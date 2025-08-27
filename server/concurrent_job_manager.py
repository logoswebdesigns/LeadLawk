#!/usr/bin/env python3
"""
Concurrent Job Manager for Multiple Industry Automation
Handles parallel execution of browser automation jobs for different industries
"""

import asyncio
import threading
import uuid
from datetime import datetime
from typing import Dict, List, Any, Optional
from dataclasses import dataclass
import logging

from container_orchestrator import get_selenium_container
from schemas import ScrapeRequest

logger = logging.getLogger(__name__)

@dataclass
class IndustryJob:
    """Represents a single industry automation job"""
    job_id: str
    industry: str
    parent_job_id: str
    status: str = "pending"
    processed: int = 0
    total: int = 0
    error_message: Optional[str] = None
    selenium_hub_url: Optional[str] = None
    created_at: datetime = None
    
    def __post_init__(self):
        if self.created_at is None:
            self.created_at = datetime.utcnow()

@dataclass
class MultiIndustryJob:
    """Represents a multi-industry automation job with concurrent execution"""
    parent_job_id: str
    location: str
    limit_per_industry: int
    total_industries: int
    industry_jobs: Dict[str, IndustryJob]
    status: str = "running"
    created_at: datetime = None
    completed_jobs: int = 0
    total_processed: int = 0
    
    def __post_init__(self):
        if self.created_at is None:
            self.created_at = datetime.utcnow()
    
    @property
    def overall_progress(self) -> float:
        """Calculate overall progress across all industry jobs"""
        if not self.industry_jobs:
            return 0.0
        
        total_expected = self.total_industries * self.limit_per_industry
        return (self.total_processed / total_expected) if total_expected > 0 else 0.0
    
    @property
    def is_complete(self) -> bool:
        """Check if all industry jobs are complete"""
        return self.completed_jobs >= self.total_industries

class ConcurrentJobManager:
    """Manages concurrent execution of multiple industry automation jobs"""
    
    def __init__(self):
        self.multi_jobs: Dict[str, MultiIndustryJob] = {}
        self.job_lock = threading.Lock()
        self.active_industry_jobs: Dict[str, IndustryJob] = {}
        
    def create_multi_industry_job(self, industries: List[str], base_params: ScrapeRequest) -> str:
        """
        Create a multi-industry job that will run concurrent automation for each industry
        
        Args:
            industries: List of industries to scrape
            base_params: Base scraping parameters
            
        Returns:
            Parent job ID for tracking the overall progress
        """
        parent_job_id = str(uuid.uuid4())
        
        # Calculate leads per industry (distribute total limit across industries)
        limit_per_industry = max(1, base_params.limit // len(industries))
        if base_params.limit % len(industries) > 0:
            limit_per_industry += 1  # Round up to ensure we don't under-deliver
        
        # Create industry jobs
        industry_jobs = {}
        for industry in industries:
            job_id = str(uuid.uuid4())
            industry_job = IndustryJob(
                job_id=job_id,
                industry=industry,
                parent_job_id=parent_job_id,
                total=limit_per_industry
            )
            industry_jobs[job_id] = industry_job
            self.active_industry_jobs[job_id] = industry_job
        
        # Create parent job
        multi_job = MultiIndustryJob(
            parent_job_id=parent_job_id,
            location=base_params.location,
            limit_per_industry=limit_per_industry,
            total_industries=len(industries),
            industry_jobs=industry_jobs
        )
        
        with self.job_lock:
            self.multi_jobs[parent_job_id] = multi_job
        
        logger.info(f"Created multi-industry job {parent_job_id} for {len(industries)} industries")
        return parent_job_id
    
    async def execute_multi_industry_job(self, parent_job_id: str, base_params: ScrapeRequest):
        """Execute all industry jobs concurrently"""
        multi_job = self.multi_jobs.get(parent_job_id)
        if not multi_job:
            logger.error(f"Multi-industry job {parent_job_id} not found")
            return
        
        logger.info(f"Starting concurrent execution for {len(multi_job.industry_jobs)} industries")
        
        # Create concurrent tasks for each industry
        tasks = []
        for industry_job in multi_job.industry_jobs.values():
            task = asyncio.create_task(
                self._execute_single_industry_job(industry_job, base_params, multi_job)
            )
            tasks.append(task)
        
        # Wait for all tasks to complete
        try:
            await asyncio.gather(*tasks, return_exceptions=True)
        except Exception as e:
            logger.error(f"Error in multi-industry job execution: {e}")
        finally:
            # Update parent job status
            with self.job_lock:
                if parent_job_id in self.multi_jobs:
                    multi_job = self.multi_jobs[parent_job_id]
                    multi_job.status = "completed" if multi_job.is_complete else "error"
    
    async def _execute_single_industry_job(self, industry_job: IndustryJob, base_params: ScrapeRequest, parent_job: MultiIndustryJob):
        """Execute a single industry automation job"""
        job_id = industry_job.job_id
        
        try:
            # Get a Selenium container for this job (falls back gracefully if Docker unavailable)
            async with get_selenium_container(job_id) as selenium_hub_url:
                industry_job.selenium_hub_url = selenium_hub_url
                industry_job.status = "running"
                
                # Import here to avoid circular imports
                from browser_automation import BrowserAutomation
                from main import add_job_log, update_job_status
                
                add_job_log(job_id, f"🚀 Starting automation for {industry_job.industry}")
                add_job_log(job_id, f"Using Selenium hub: {selenium_hub_url}")
                
                # Create industry-specific parameters
                industry_params = ScrapeRequest(
                    industry=industry_job.industry,
                    location=base_params.location,
                    limit=industry_job.total,
                    min_rating=base_params.min_rating,
                    min_reviews=base_params.min_reviews,
                    recent_days=base_params.recent_days,
                    mock=base_params.mock,
                    use_browser_automation=base_params.use_browser_automation,
                    use_profile=base_params.use_profile,
                    headless=base_params.headless,
                    requires_website=base_params.requires_website,
                    recent_review_months=base_params.recent_review_months,
                    min_photos=base_params.min_photos,
                    min_description_length=base_params.min_description_length
                )
                
                # Override the Selenium hub URL in environment
                import os
                original_hub_url = os.environ.get('SELENIUM_HUB_URL')
                
                # Only override if we got a specific hub URL (Docker available)
                if selenium_hub_url != original_hub_url:
                    os.environ['SELENIUM_HUB_URL'] = selenium_hub_url
                
                try:
                    # Initialize browser automation with specific hub URL
                    automation = BrowserAutomation(
                        use_profile=industry_params.use_profile,
                        headless=industry_params.headless,
                        job_id=job_id
                    )
                    
                    # Execute the automation
                    leads_found = automation.search_and_extract_leads(
                        industry=industry_job.industry,
                        location=base_params.location,
                        limit=industry_job.total,
                        min_rating=base_params.min_rating,
                        min_reviews=base_params.min_reviews,
                        requires_website=base_params.requires_website,
                        recent_review_months=base_params.recent_review_months,
                        min_photos=base_params.min_photos,
                        min_description_length=base_params.min_description_length,
                        progress_callback=lambda processed, total: self._update_job_progress(
                            job_id, parent_job.parent_job_id, processed, total
                        )
                    )
                    
                    industry_job.processed = len(leads_found) if leads_found else 0
                    industry_job.status = "completed"
                    
                    add_job_log(job_id, f"✅ Completed {industry_job.industry}: {industry_job.processed} leads")
                    
                finally:
                    # Restore original hub URL
                    if original_hub_url:
                        os.environ['SELENIUM_HUB_URL'] = original_hub_url
                    
                    # Clean up automation
                    if 'automation' in locals():
                        automation.cleanup()
        
        except Exception as e:
            industry_job.status = "error"
            industry_job.error_message = str(e)
            logger.error(f"Industry job {job_id} ({industry_job.industry}) failed: {e}")
            
            # Import here to avoid circular imports
            from main import add_job_log
            add_job_log(job_id, f"❌ Error in {industry_job.industry}: {str(e)}")
        
        finally:
            # Update parent job completion count
            with self.job_lock:
                parent_job.completed_jobs += 1
                parent_job.total_processed += industry_job.processed
                
                # Clean up from active jobs
                if job_id in self.active_industry_jobs:
                    del self.active_industry_jobs[job_id]
    
    def _update_job_progress(self, job_id: str, parent_job_id: str, processed: int, total: int):
        """Update progress for both individual and parent jobs"""
        # Update individual job
        if job_id in self.active_industry_jobs:
            self.active_industry_jobs[job_id].processed = processed
        
        # Update parent job
        with self.job_lock:
            if parent_job_id in self.multi_jobs:
                parent_job = self.multi_jobs[parent_job_id]
                
                # Calculate total progress across all industry jobs
                total_processed = sum(job.processed for job in parent_job.industry_jobs.values())
                total_expected = parent_job.total_industries * parent_job.limit_per_industry
                
                parent_job.total_processed = total_processed
                
                # Import here to avoid circular imports
                from main import update_job_status, add_job_log
                
                update_job_status(
                    parent_job_id, 
                    parent_job.status, 
                    total_processed, 
                    total_expected
                )
                
                # Log progress
                progress_pct = (total_processed / total_expected * 100) if total_expected > 0 else 0
                add_job_log(parent_job_id, 
                    f"Overall progress: {total_processed}/{total_expected} ({progress_pct:.1f}%)")
    
    def get_job_status(self, parent_job_id: str) -> Optional[Dict[str, Any]]:
        """Get status of a multi-industry job"""
        with self.job_lock:
            if parent_job_id not in self.multi_jobs:
                return None
            
            multi_job = self.multi_jobs[parent_job_id]
            return {
                "parent_job_id": parent_job_id,
                "status": multi_job.status,
                "location": multi_job.location,
                "total_industries": multi_job.total_industries,
                "completed_jobs": multi_job.completed_jobs,
                "total_processed": multi_job.total_processed,
                "overall_progress": multi_job.overall_progress,
                "industry_jobs": [
                    {
                        "job_id": job.job_id,
                        "industry": job.industry,
                        "status": job.status,
                        "processed": job.processed,
                        "total": job.total,
                        "error_message": job.error_message
                    }
                    for job in multi_job.industry_jobs.values()
                ]
            }
    
    def cancel_job(self, parent_job_id: str):
        """Cancel a multi-industry job and all its industry jobs"""
        with self.job_lock:
            if parent_job_id in self.multi_jobs:
                multi_job = self.multi_jobs[parent_job_id]
                multi_job.status = "cancelled"
                
                # Cancel all industry jobs
                for industry_job in multi_job.industry_jobs.values():
                    if industry_job.status == "running":
                        industry_job.status = "cancelled"
                
                logger.info(f"Cancelled multi-industry job {parent_job_id}")
    
    def cleanup_completed_jobs(self, max_age_hours: int = 24):
        """Clean up completed jobs older than specified hours"""
        from datetime import timedelta
        
        cutoff_time = datetime.utcnow() - timedelta(hours=max_age_hours)
        
        with self.job_lock:
            jobs_to_remove = [
                job_id for job_id, job in self.multi_jobs.items()
                if job.created_at < cutoff_time and job.status in ("completed", "error", "cancelled")
            ]
            
            for job_id in jobs_to_remove:
                del self.multi_jobs[job_id]
                logger.info(f"Cleaned up old job: {job_id}")

# Global job manager instance
concurrent_job_manager = ConcurrentJobManager()