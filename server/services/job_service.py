"""
Job service for business logic.
Pattern: Service Layer Pattern - encapsulates job management logic.
Single Responsibility: Job orchestration and execution.
"""

from typing import Dict, Any, Optional
from fastapi import BackgroundTasks
import uuid
import logging

from ..schemas import BrowserAutomationRequest
from ..job_management import (
    create_job, job_statuses, update_job_status,
    cleanup_old_jobs
)
from ..scraper_runner import run_scraper
from ..parallel_job_executor import parallel_executor
from ..database import SessionLocal
from ..models import Lead

logger = logging.getLogger(__name__)


class JobService:
    """
    Service class for job operations.
    Pattern: Facade Pattern - simplifies complex job operations.
    """
    
    def create_browser_job(
        self,
        job_id: str,
        request: BrowserAutomationRequest,
        background_tasks: BackgroundTasks
    ) -> Dict[str, Any]:
        """Create and execute a browser automation job."""
        cleanup_old_jobs()
        
        job_data = {
            "id": job_id,
            "status": "created",
            "processed": 0,
            "total": 0,
            "message": "Job created",
            "industry": request.industry,
            "location": request.location,
            "max_results": request.max_results
        }
        
        create_job(job_id, job_data)
        
        background_tasks.add_task(
            run_scraper,
            job_id,
            request.dict()
        )
        
        return {
            "job_id": job_id,
            "status": "created",
            "message": "Job created successfully"
        }
    
    def create_parallel_jobs(
        self,
        parent_job_id: str,
        request: BrowserAutomationRequest,
        background_tasks: BackgroundTasks
    ) -> Dict[str, Any]:
        """Create and execute parallel browser automation jobs."""
        config = request.dict()
        config["parent_job_id"] = parent_job_id
        
        update_job_status(
            parent_job_id,
            "created",
            message="Parallel job created",
            industry=request.industry,
            location=request.location,
            parallel_count=config.get("parallel_count", 5)
        )
        
        background_tasks.add_task(
            parallel_executor.execute_parallel_jobs,
            parent_job_id,
            config
        )
        
        return {
            "parent_job_id": parent_job_id,
            "status": "created",
            "parallel_count": config.get("parallel_count", 5)
        }
    
    def get_parallel_job_status(self, parent_job_id: str) -> Dict[str, Any]:
        """Get status of parallel job execution."""
        parent_status = job_statuses.get(parent_job_id, {})
        child_jobs = [
            job for job_id, job in job_statuses.items()
            if job.get("parent_job_id") == parent_job_id
        ]
        
        return {
            "parent": parent_status,
            "children": child_jobs,
            "summary": {
                "total": len(child_jobs),
                "completed": sum(1 for j in child_jobs if j.get("status") == "completed"),
                "failed": sum(1 for j in child_jobs if j.get("status") == "failed"),
                "running": sum(1 for j in child_jobs if j.get("status") == "running")
            }
        }
    
    def run_pagespeed_for_job(
        self,
        job_id: str,
        background_tasks: BackgroundTasks
    ) -> Dict[str, Any]:
        """Run PageSpeed analysis for all leads from a job."""
        db = SessionLocal()
        try:
            leads = db.query(Lead).filter(Lead.job_id == job_id).all()
            
            if not leads:
                return {"error": "No leads found for this job"}
            
            from ..pagespeed_analyzer import analyze_pagespeed_batch
            background_tasks.add_task(analyze_pagespeed_batch, [l.id for l in leads])
            
            return {
                "message": f"Started PageSpeed analysis for {len(leads)} leads",
                "lead_count": len(leads)
            }
        finally:
            db.close()