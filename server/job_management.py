#!/usr/bin/env python3
"""
Simple in-memory job management (matching original approach)
"""

import os
import uuid
import threading
from pathlib import Path
from datetime import datetime
from typing import Dict, Optional, List


# Global job status tracking (matches original implementation)
job_statuses: Dict[str, Dict] = {}
job_threads: Dict[str, threading.Thread] = {}


def update_job_status(job_id: str, status: str, processed: int = 0, total: int = 0, message: Optional[str] = None, **kwargs):
    """Update job status in memory while preserving existing data"""
    # Get existing job status to preserve additional data
    existing_job = job_statuses.get(job_id, {})
    
    # Create updated status
    job_status = {
        "id": job_id,
        "status": status,
        "processed": processed,
        "total": total,
        "message": message,
        "timestamp": datetime.utcnow().isoformat()
    }
    
    # Preserve existing additional data (industry, location, etc.)
    for key, value in existing_job.items():
        if key not in job_status and key not in ["status", "processed", "total", "message", "timestamp"]:
            job_status[key] = value
    
    # Add/override with any new additional parameters
    job_status.update(kwargs)
    
    job_statuses[job_id] = job_status


def cleanup_old_jobs(max_jobs=3):
    """Clean up old screenshots to prevent disk space issues"""
    try:
        screenshots_dir = Path("screenshots")
        if not screenshots_dir.exists():
            return
        
        # Get all screenshot files
        screenshot_files = list(screenshots_dir.glob("job_*.png"))
        
        if len(screenshot_files) <= max_jobs * 10:  # Keep reasonable number per job
            return
        
        # Sort by creation time and keep only recent ones
        screenshot_files.sort(key=lambda x: x.stat().st_mtime, reverse=True)
        files_to_delete = screenshot_files[max_jobs * 10:]
        
        for file in files_to_delete:
            try:
                # Only delete non-business screenshots
                if "_business_" not in file.name:
                    os.remove(file)
                    print(f"🗑️ Cleaned up old screenshot: {file.name}")
            except Exception as e:
                print(f"❌ Error deleting screenshot {file.name}: {str(e)}")
        
        print(f"✅ Screenshot cleanup complete")
        
    except Exception as e:
        print(f"❌ Error during cleanup: {e}")


def add_job_log(job_id: str, log_message: str):
    """Add a log entry for a specific job and store in job status"""
    print(f"[JOB {job_id}] {log_message}")
    
    # Store logs in the job status object for retrieval
    if job_id not in job_statuses:
        job_statuses[job_id] = {}
    
    if 'logs' not in job_statuses[job_id]:
        job_statuses[job_id]['logs'] = []
    
    # Add log entry with timestamp
    log_entry = {
        "message": log_message,
        "timestamp": datetime.utcnow().isoformat()
    }
    job_statuses[job_id]['logs'].append(log_entry)
    
    # Keep only last 100 logs to prevent memory issues
    if len(job_statuses[job_id]['logs']) > 100:
        job_statuses[job_id]['logs'] = job_statuses[job_id]['logs'][-100:]


def create_job(params) -> str:
    """Create a new job with in-memory tracking"""
    job_id = str(uuid.uuid4())
    update_job_status(job_id, "pending", message="Job created, waiting to start...")
    return job_id


def get_job_by_id(job_id: str):
    """Get job from in-memory storage"""
    return job_statuses.get(job_id)


def get_all_jobs():
    """Get all jobs from in-memory storage"""
    return list(job_statuses.values())


def cancel_job(job_id: str) -> bool:
    """Cancel a running job"""
    try:
        if job_id in job_statuses:
            update_job_status(job_id, "cancelled", message="Job cancelled by user")
            return True
        return False
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