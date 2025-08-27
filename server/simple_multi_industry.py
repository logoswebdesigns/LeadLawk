#!/usr/bin/env python3
"""
Simple Multi-Industry Job Processor
Processes multiple industries sequentially using a single Selenium container
This is a bulletproof fallback when Docker orchestration is not available
"""

import logging
import threading
import uuid
from datetime import datetime
from typing import Dict, List, Any, Optional

from schemas import ScrapeRequest

logger = logging.getLogger(__name__)

class SimpleMultiIndustryProcessor:
    """
    Simple multi-industry processor that runs industries sequentially
    Uses the existing single Selenium container infrastructure
    """
    
    def __init__(self):
        self.active_jobs: Dict[str, Dict[str, Any]] = {}
        self.job_lock = threading.Lock()
    
    def create_multi_industry_job(self, industries: List[str], base_params: ScrapeRequest) -> str:
        """Create a multi-industry job for sequential processing"""
        parent_job_id = str(uuid.uuid4())
        
        # Calculate leads per industry (distribute total limit across industries)
        limit_per_industry = max(1, base_params.limit // len(industries))
        if base_params.limit % len(industries) > 0:
            limit_per_industry += 1  # Round up to ensure we don't under-deliver
        
        job_info = {
            "parent_job_id": parent_job_id,
            "industries": industries,
            "location": base_params.location,
            "limit_per_industry": limit_per_industry,
            "total_industries": len(industries),
            "completed_industries": 0,
            "total_processed": 0,
            "current_industry": None,
            "status": "running",
            "created_at": datetime.utcnow().isoformat(),
            "base_params": base_params
        }
        
        with self.job_lock:
            self.active_jobs[parent_job_id] = job_info
        
        logger.info(f"Created simple multi-industry job {parent_job_id} for {len(industries)} industries")
        return parent_job_id
    
    async def execute_multi_industry_job_sequential(self, parent_job_id: str):
        """Execute industries sequentially using existing automation"""
        job_info = self.active_jobs.get(parent_job_id)
        if not job_info:
            logger.error(f"Job {parent_job_id} not found")
            return
        
        industries = job_info["industries"]
        base_params = job_info["base_params"]
        
        logger.info(f"Starting sequential execution for {len(industries)} industries")
        
        # Import here to avoid circular imports
        from main import add_job_log, update_job_status
        from browser_automation import BrowserAutomation
        
        total_leads_found = 0
        
        try:
            for i, industry in enumerate(industries, 1):
                # Update current industry
                with self.job_lock:
                    if parent_job_id in self.active_jobs:
                        self.active_jobs[parent_job_id]["current_industry"] = industry
                
                add_job_log(parent_job_id, f"🚀 Processing industry {i}/{len(industries)}: {industry}")
                
                # Create industry-specific parameters
                industry_params = ScrapeRequest(
                    industry=industry,
                    location=base_params.location,
                    limit=job_info["limit_per_industry"],
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
                
                # Create industry-specific automation for this industry only
                automation = None
                try:
                    add_job_log(parent_job_id, f"🔧 Initializing browser for {industry}...")
                    
                    # Initialize browser automation
                    automation = BrowserAutomation(
                        use_profile=industry_params.use_profile,
                        headless=industry_params.headless,
                        job_id=parent_job_id  # Use parent job ID for logging
                    )
                    
                    add_job_log(parent_job_id, f"✅ Browser ready for {industry}")
                    
                    # Navigate to Google Maps and search
                    search_query = f"{industry} near {base_params.location}"
                    add_job_log(parent_job_id, f"🔍 Searching Google Maps for: {search_query}")
                    
                    results = automation.search_google_maps(
                        query=search_query,
                        limit=job_info["limit_per_industry"],
                        min_rating=base_params.min_rating,
                        min_reviews=base_params.min_reviews,
                        requires_website=base_params.requires_website,
                        recent_review_months=base_params.recent_review_months,
                        min_photos=base_params.min_photos,
                        min_description_length=base_params.min_description_length
                    )
                    
                    # CRITICAL: Save leads to database after each industry
                    industry_leads_saved = 0
                    if results:
                        from database import SessionLocal
                        from models import Lead, LeadStatus
                        from datetime import datetime
                        
                        db = SessionLocal()
                        try:
                            for result in results:
                                business_name = result.get('name', 'Unknown Business')
                                phone = result.get('phone') or 'No phone'  # Handle missing phone numbers like regular automation
                                
                                # Skip if missing essential data
                                if not business_name or business_name == 'Unknown Business':
                                    continue
                                
                                # Check for duplicates (same as regular automation)
                                existing_lead = db.query(Lead).filter(
                                    Lead.business_name == business_name,
                                    Lead.phone == phone
                                ).first()
                                
                                if existing_lead:
                                    add_job_log(parent_job_id, f"Duplicate: {business_name} (phone: {phone}) - skipped")
                                    continue
                                
                                # Also check for duplicate by business name and location
                                name_location_duplicate = db.query(Lead).filter(
                                    Lead.business_name == business_name,
                                    Lead.location == base_params.location,
                                    Lead.industry == industry
                                ).first()
                                
                                if name_location_duplicate:
                                    add_job_log(parent_job_id, f"Duplicate: {business_name} (already exists in {base_params.location}) - skipped")
                                    continue
                                
                                # Create new lead
                                lead = Lead(
                                    business_name=business_name,
                                    phone=phone,
                                    website_url=result.get('website'),
                                    profile_url=result.get('url', ''),
                                    rating=float(result.get('rating', 0.0)),
                                    review_count=int(result.get('reviews', 0)),
                                    last_review_date=result.get('last_review_date'),
                                    location=base_params.location,
                                    industry=industry,  # Use the current industry being processed
                                    source="multi_industry_automation",
                                    status=LeadStatus.NEW,
                                    has_website=result.get('website') is not None,
                                    is_candidate=result.get('website') is None,
                                    meets_rating_threshold=float(result.get('rating', 0)) >= base_params.min_rating,
                                    has_recent_reviews=result.get('has_recent_reviews', False),
                                    created_at=datetime.utcnow(),
                                    updated_at=datetime.utcnow()
                                )
                                db.add(lead)
                                industry_leads_saved += 1
                                add_job_log(parent_job_id, f"💾 Saved: {business_name} - ⭐ {lead.rating} ({lead.review_count} reviews)")
                            
                            # Commit leads for this industry
                            db.commit()
                            add_job_log(parent_job_id, f"✅ {industry}: Found {len(results) if results else 0} leads, saved {industry_leads_saved} new leads")
                            
                        except Exception as db_error:
                            db.rollback()
                            add_job_log(parent_job_id, f"❌ Database error for {industry}: {str(db_error)}")
                            logger.error(f"Database error for {industry}: {db_error}")
                        finally:
                            db.close()
                    else:
                        add_job_log(parent_job_id, f"✅ {industry}: No leads found")
                    
                    total_leads_found += industry_leads_saved
                    
                except Exception as e:
                    add_job_log(parent_job_id, f"❌ Error in {industry}: {str(e)}")
                    logger.error(f"Industry {industry} failed: {e}")
                
                finally:
                    # CRITICAL: Always clean up automation to free Selenium session
                    if automation is not None:
                        try:
                            add_job_log(parent_job_id, f"🧹 Closing browser for {industry}...")
                            automation.close()
                            add_job_log(parent_job_id, f"✅ Browser closed for {industry}")
                        except Exception as cleanup_error:
                            add_job_log(parent_job_id, f"⚠️ Browser cleanup warning for {industry}: {cleanup_error}")
                            logger.warning(f"Browser close error for {industry}: {cleanup_error}")
                    
                    # Add a small delay between industries to ensure cleanup completes
                    import asyncio
                    await asyncio.sleep(2)
                
                # Update progress
                with self.job_lock:
                    if parent_job_id in self.active_jobs:
                        self.active_jobs[parent_job_id]["completed_industries"] = i
                        self.active_jobs[parent_job_id]["total_processed"] = total_leads_found
                
                # Update job status
                progress_pct = (i / len(industries) * 100)
                update_job_status(
                    parent_job_id,
                    "running",
                    total_leads_found,
                    base_params.limit
                )
                add_job_log(parent_job_id, f"Progress: {i}/{len(industries)} industries ({progress_pct:.1f}%)")
            
            # Mark as completed
            with self.job_lock:
                if parent_job_id in self.active_jobs:
                    self.active_jobs[parent_job_id]["status"] = "completed"
            
            update_job_status(parent_job_id, "done", total_leads_found, base_params.limit)
            add_job_log(parent_job_id, f"🎉 Multi-industry automation completed! Total leads: {total_leads_found}")
            
        except Exception as e:
            logger.error(f"Multi-industry job {parent_job_id} failed: {e}")
            
            with self.job_lock:
                if parent_job_id in self.active_jobs:
                    self.active_jobs[parent_job_id]["status"] = "error"
            
            update_job_status(parent_job_id, "error", total_leads_found, base_params.limit, str(e))
            add_job_log(parent_job_id, f"❌ Multi-industry automation failed: {str(e)}")
    
    def get_job_status(self, parent_job_id: str) -> Optional[Dict[str, Any]]:
        """Get status of a multi-industry job"""
        with self.job_lock:
            if parent_job_id not in self.active_jobs:
                return None
            
            job_info = self.active_jobs[parent_job_id]
            
            return {
                "parent_job_id": parent_job_id,
                "status": job_info["status"],
                "location": job_info["location"],
                "total_industries": job_info["total_industries"],
                "completed_industries": job_info["completed_industries"],
                "total_processed": job_info["total_processed"],
                "current_industry": job_info.get("current_industry"),
                "overall_progress": job_info["completed_industries"] / job_info["total_industries"] if job_info["total_industries"] > 0 else 0,
                "industries": job_info["industries"]
            }
    
    def cancel_job(self, parent_job_id: str):
        """Cancel a multi-industry job"""
        with self.job_lock:
            if parent_job_id in self.active_jobs:
                self.active_jobs[parent_job_id]["status"] = "cancelled"
                logger.info(f"Cancelled multi-industry job {parent_job_id}")
    
    def cleanup_completed_jobs(self, max_age_hours: int = 24):
        """Clean up completed jobs older than specified hours"""
        from datetime import timedelta
        
        cutoff_time = datetime.utcnow() - timedelta(hours=max_age_hours)
        
        with self.job_lock:
            jobs_to_remove = []
            for job_id, job_info in self.active_jobs.items():
                try:
                    created_at = datetime.fromisoformat(job_info["created_at"])
                    if created_at < cutoff_time and job_info["status"] in ("completed", "error", "cancelled"):
                        jobs_to_remove.append(job_id)
                except:
                    pass
            
            for job_id in jobs_to_remove:
                del self.active_jobs[job_id]
                logger.info(f"Cleaned up old job: {job_id}")

# Global simple processor instance
simple_multi_industry_processor = SimpleMultiIndustryProcessor()