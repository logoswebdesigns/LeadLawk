"""
Jobs router for scraping job management.
Pattern: MVC Controller - thin controllers delegating to services.
Single Responsibility: Job endpoint handling only.
"""

from fastapi import APIRouter, BackgroundTasks, HTTPException
from typing import Dict, Any, List
import uuid

from ..schemas import BrowserAutomationRequest, JobResponse
from ..services.job_service import JobService
from ..job_management import job_statuses, get_all_jobs, get_job_by_id, cancel_job

router = APIRouter(
    prefix="/jobs",
    tags=["jobs"],
)


@router.post("/browser", response_model=Dict[str, Any])
async def create_browser_job(
    request: BrowserAutomationRequest,
    background_tasks: BackgroundTasks
):
    """Create a new browser automation job."""
    service = JobService()
    job_id = str(uuid.uuid4())
    
    job_response = service.create_browser_job(
        job_id=job_id,
        request=request,
        background_tasks=background_tasks
    )
    
    return job_response


@router.get("")
async def list_jobs():
    """Get all jobs with their current status."""
    return get_all_jobs()


@router.get("/{job_id}")
async def get_job(job_id: str):
    """Get a specific job by ID."""
    job = get_job_by_id(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    return job


@router.post("/{job_id}/cancel")
async def cancel_job_endpoint(job_id: str):
    """Cancel a running job."""
    success = cancel_job(job_id)
    if not success:
        raise HTTPException(status_code=404, detail="Job not found")
    return {"message": "Job cancelled successfully"}


@router.get("/{job_id}/logs")
async def get_job_logs(job_id: str):
    """Get logs for a specific job."""
    if job_id not in job_statuses:
        raise HTTPException(status_code=404, detail="Job not found")
    return {"logs": job_statuses[job_id].get("logs", [])}


@router.get("/{job_id}/screenshots")
async def get_job_screenshots(job_id: str):
    """Get screenshots for a specific job."""
    from ..job_management import get_job_screenshots
    screenshots = get_job_screenshots(job_id)
    return {"screenshots": screenshots}


@router.post("/parallel", response_model=Dict[str, Any])
async def create_parallel_jobs(
    request: BrowserAutomationRequest,
    background_tasks: BackgroundTasks
):
    """Create parallel browser automation jobs."""
    service = JobService()
    parent_job_id = str(uuid.uuid4())
    
    result = service.create_parallel_jobs(
        parent_job_id=parent_job_id,
        request=request,
        background_tasks=background_tasks
    )
    
    return result


@router.get("/parallel/{parent_job_id}/status")
async def get_parallel_job_status(parent_job_id: str):
    """Get status of parallel job execution."""
    service = JobService()
    return service.get_parallel_job_status(parent_job_id)


@router.post("/{job_id}/pagespeed")
async def run_pagespeed_for_job(job_id: str, background_tasks: BackgroundTasks):
    """Run PageSpeed analysis for all leads from a job."""
    service = JobService()
    return service.run_pagespeed_for_job(job_id, background_tasks)