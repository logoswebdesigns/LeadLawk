#!/usr/bin/env python3
"""
Job management operations and utilities
"""

import os
import uuid
import threading
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, Optional, List
from database import SessionLocal
from models import Lead
from schemas import ScrapeRequest, JobResponse


# Global job status tracking
job_statuses: Dict[str, Dict] = {}
job_threads: Dict[str, threading.Thread] = {}


def update_job_status(job_id: str, status: str, processed: int = 0, total: int = 0, message: Optional[str] = None):
    """Update job status in memory"""
    job_statuses[job_id] = {
        "status": status,
        "processed": processed,
        "total": total,
        "message": message,
        "timestamp": datetime.utcnow().isoformat()
    }


def cleanup_old_jobs(max_jobs=3):
    """Clean up old jobs from database and file system"""
    try:
        db = SessionLocal()
        
        # Get jobs ordered by creation date (newest first)
        all_jobs = db.query(Job).order_by(Job.created_at.desc()).all()
        
        if len(all_jobs) <= max_jobs:
            print(f"Only {len(all_jobs)} jobs found, no cleanup needed")
            db.close()
            return
        
        # Jobs to delete (keep most recent max_jobs)
        jobs_to_delete = all_jobs[max_jobs:]
        
        print(f"Cleaning up {len(jobs_to_delete)} old jobs (keeping {max_jobs} most recent)")
        
        screenshots_dir = Path("screenshots")
        deleted_count = 0
        
        for job in jobs_to_delete:
            job_id = job.id
            
            # Delete screenshot files for this job, but preserve business screenshots
            if screenshots_dir.exists():
                for filename in os.listdir(screenshots_dir):
                    if filename.startswith(f"job_{job_id}_"):
                        # Only delete non-business screenshots
                        if "_business_" not in filename:
                            screenshot_path = screenshots_dir / filename
                            os.remove(screenshot_path)
                            deleted_count += 1
                        else:
                            print(f"    🏢 Preserving business screenshot: {filename}")
            
            # Remove from in-memory tracking
            if job_id in job_statuses:
                del job_statuses[job_id]
            if job_id in job_threads:
                del job_threads[job_id]
            
            # Delete from database
            db.delete(job)
        
        db.commit()
        print(f"✅ Cleaned up {len(jobs_to_delete)} jobs and {deleted_count} screenshot files")
        
    except Exception as e:
        print(f"❌ Error during cleanup: {e}")
        db.rollback()
    finally:
        db.close()


def add_job_log(job_id: str, log_message: str):
    """Add a log entry for a specific job"""
    try:
        db = SessionLocal()
        job = db.query(Job).filter(Job.id == job_id).first()
        if job:
            # Create log entry format
            timestamp = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")
            formatted_log = f"[{timestamp}] {log_message}"
            
            # Append to existing logs
            if job.logs:
                job.logs += f"\n{formatted_log}"
            else:
                job.logs = formatted_log
            
            db.commit()
        db.close()
    except Exception as e:
        print(f"Error adding job log: {e}")


def create_job(params: ScrapeRequest) -> str:
    """Create a new job in the database"""
    try:
        job_id = str(uuid.uuid4())
        
        db = SessionLocal()
        new_job = Job(
            id=job_id,
            query=params.query,
            industry=params.industry,
            limit=params.limit,
            min_rating=params.min_rating,
            min_reviews=params.min_reviews,
            requires_website=params.requires_website,
            recent_review_months=params.recent_review_months,
            status=JobStatus.PENDING,
            created_at=datetime.utcnow()
        )
        
        db.add(new_job)
        db.commit()
        db.close()
        
        # Initialize job status
        update_job_status(job_id, "pending", message="Job created, waiting to start...")
        
        return job_id
        
    except Exception as e:
        print(f"Error creating job: {e}")
        raise


def get_job_by_id(job_id: str) -> Optional[Job]:
    """Get job from database by ID"""
    try:
        db = SessionLocal()
        job = db.query(Job).filter(Job.id == job_id).first()
        db.close()
        return job
    except Exception as e:
        print(f"Error getting job {job_id}: {e}")
        return None


def get_all_jobs() -> List[Job]:
    """Get all jobs from database"""
    try:
        db = SessionLocal()
        jobs = db.query(Job).order_by(Job.created_at.desc()).limit(20).all()
        db.close()
        return jobs
    except Exception as e:
        print(f"Error getting jobs: {e}")
        return []


def cancel_job(job_id: str) -> bool:
    """Cancel a running job"""
    try:
        # Update status in memory and database
        update_job_status(job_id, "cancelled", message="Job cancelled by user")
        
        # If there's a thread running, we can't directly stop it,
        # but the automation should check the status periodically
        if job_id in job_threads:
            thread = job_threads[job_id]
            print(f"Job {job_id} thread exists, setting cancel flag")
        
        return True
    except Exception as e:
        print(f"Error cancelling job {job_id}: {e}")
        return False


def get_job_screenshots(job_id: str) -> List[str]:
    """Get all screenshots for a specific job"""
    try:
        screenshots_dir = Path("screenshots")
        if not screenshots_dir.exists():
            return []
        
        screenshots = []
        for filename in os.listdir(screenshots_dir):
            if filename.startswith(f"job_{job_id}_") and filename.endswith(('.png', '.jpg', '.jpeg')):
                screenshots.append(filename)
        
        # Sort by creation time
        screenshots.sort(key=lambda x: os.path.getctime(screenshots_dir / x))
        return screenshots
        
    except Exception as e:
        print(f"Error getting screenshots for job {job_id}: {e}")
        return []