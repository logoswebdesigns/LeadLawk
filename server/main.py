#!/usr/bin/env python3
"""
Refactored FastAPI main application - orchestrates all components
"""

import os
import json
import asyncio
import logging
import subprocess
import time
import uuid
from pathlib import Path
from typing import Dict, Any, List, Optional
from datetime import datetime

from fastapi import FastAPI, HTTPException, BackgroundTasks, WebSocket, WebSocketDisconnect, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import StreamingResponse, FileResponse
from logging.handlers import RotatingFileHandler
from sqlalchemy import func

# Local imports
from database import SessionLocal, init_db
from sqlalchemy.orm import selectinload
from models import Lead, LeadStatus, SalesPitch, LeadTimelineEntry, TimelineEntryType
from schemas import (BrowserAutomationRequest, JobResponse, LeadResponse, LeadUpdate, 
                    LeadTimelineEntryUpdate, ConversionModelResponse, ConversionScoringResponse,
                    SalesPitchResponse, SalesPitchCreate, SalesPitchUpdate, LeadUpdateRequest)

# Import our refactored modules
from job_management import (
    create_job, get_job_by_id, get_all_jobs, cancel_job, cleanup_old_jobs,
    get_job_screenshots, job_statuses
)
from lead_management import (
    get_all_leads, get_lead_by_id, delete_lead_by_id, delete_all_leads,
    delete_mock_leads, update_lead, update_lead_timeline_entry
)
from scraper_runner import run_scraper, _scrape_prerequisites
from websocket_manager import job_websocket_manager, log_websocket_manager, pagespeed_websocket_manager
from analytics_engine import AnalyticsEngine
from parallel_job_executor import parallel_executor


# Initialize FastAPI app
app = FastAPI(title="LeadLoq API")

# Initialize logger
logger = logging.getLogger(__name__)

# Custom robust rotating file handler
class RobustRotatingFileHandler(RotatingFileHandler):
    def doRollover(self):
        try:
            super().doRollover()
        except (OSError, IOError):
            pass
    
    def emit(self, record):
        try:
            super().emit(record)
        except (OSError, IOError, ValueError):
            pass


# Configure logging
LOG_PATH = Path(__file__).resolve().parent / "server.log"
LOG_PATH.parent.mkdir(parents=True, exist_ok=True)

try:
    file_handler = RobustRotatingFileHandler(
        LOG_PATH, maxBytes=50*1024*1024, backupCount=3
    )
    file_handler.setLevel(logging.INFO)
    formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
    file_handler.setFormatter(formatter)
    
    root_logger = logging.getLogger()
    root_logger.setLevel(logging.INFO)
    root_logger.addHandler(file_handler)
    
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(formatter)
    root_logger.addHandler(console_handler)
    
except Exception as e:
    print(f"Failed to setup logging: {e}")


# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount static files for screenshots
app.mount("/screenshots", StaticFiles(directory="screenshots"), name="screenshots")
app.mount("/website_screenshots", StaticFiles(directory="website_screenshots"), name="website_screenshots")


# Startup event
@app.on_event("startup")
async def startup_event():
    """Initialize database and clean up old jobs"""
    init_db()
    
    # Run conversion scoring migration if needed
    try:
        import sqlite3
        conn = sqlite3.connect('/app/db/leadloq.db')
        cursor = conn.cursor()
        
        # Check if leads table exists
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='leads'")
        if cursor.fetchone():
            # Check if conversion score columns exist
            cursor.execute("PRAGMA table_info(leads)")
            columns = [col[1] for col in cursor.fetchall()]
            
            logger.info(f"Checking columns: found {len(columns)} columns in leads table")
            
            if 'conversion_score' not in columns:
                logger.info("Running conversion scoring migration...")
                
                # Add conversion scoring fields
                cursor.execute("ALTER TABLE leads ADD COLUMN conversion_score REAL")
                cursor.execute("ALTER TABLE leads ADD COLUMN conversion_score_calculated_at TIMESTAMP")
                cursor.execute("ALTER TABLE leads ADD COLUMN conversion_score_factors TEXT")
                
                # Create index
                cursor.execute("CREATE INDEX IF NOT EXISTS idx_leads_conversion_score ON leads(conversion_score)")
                
                # Create conversion_model table
                cursor.execute("""
                    CREATE TABLE IF NOT EXISTS conversion_model (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        model_version VARCHAR NOT NULL,
                        feature_weights TEXT NOT NULL,
                        feature_importance TEXT,
                        model_accuracy REAL,
                        training_samples INTEGER,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        is_active BOOLEAN DEFAULT 1,
                        total_conversions INTEGER DEFAULT 0,
                        total_leads INTEGER DEFAULT 0,
                        baseline_conversion_rate REAL,
                        precision_score REAL,
                        recall_score REAL,
                        f1_score REAL
                    )
                """)
                
                conn.commit()
                logger.info("✅ Conversion scoring migration completed")
            else:
                logger.info("Conversion score columns already exist")
        else:
            logger.info("No leads table found, skipping conversion migration")
        
        conn.close()
    except Exception as e:
        logger.error(f"Migration error (non-fatal): {e}")
    
    cleanup_old_jobs()


# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        db = SessionLocal()
        from sqlalchemy import text
        db.execute(text("SELECT 1"))
        db.close()
        return {"status": "healthy", "database": "connected"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database connection failed: {str(e)}")


# Diagnostics endpoint
@app.get("/diagnostics")
async def get_diagnostics():
    """Get system diagnostics"""
    try:
        db = SessionLocal()
        
        # Database stats
        lead_count = db.query(Lead).count()
        job_count = len(job_statuses)  # Use in-memory job tracking
        
        # File system stats
        screenshots_dir = Path("screenshots")
        screenshot_count = len(list(screenshots_dir.glob("*.png"))) if screenshots_dir.exists() else 0
        
        # Memory stats
        active_jobs = len([s for s in job_statuses.values() if s.get("status") == "running"])
        
        db.close()
        
        return {
            "database": {
                "leads": lead_count,
                "jobs": job_count
            },
            "filesystem": {
                "screenshots": screenshot_count
            },
            "runtime": {
                "active_jobs": active_jobs,
                "job_statuses": len(job_statuses)
            }
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Diagnostics failed: {str(e)}")


# Job Management Endpoints
@app.post("/jobs/browser", response_model=Dict[str, Any])
async def start_browser_automation(params: BrowserAutomationRequest, background_tasks: BackgroundTasks):
    """Start browser automation job (backward compatibility with Flutter app)"""
    try:
        # Check prerequisites
        ready, errors = _scrape_prerequisites()
        if not ready:
            raise HTTPException(status_code=500, detail=f"Prerequisites not met: {', '.join(errors)}")
        
        # Create job
        job_id = create_job(params)
        
        # Start scraper in background
        background_tasks.add_task(run_scraper, job_id, params)
        
        return {
            "job_id": job_id, 
            "status": "running",
            "message": "Browser automation started",
            "scraper_type": "browser"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to start automation: {str(e)}")


@app.get("/jobs")
async def get_jobs():
    """Get all jobs"""
    try:
        jobs = get_all_jobs()
        return jobs  # Jobs are already dictionaries in the in-memory system
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get jobs: {str(e)}")


@app.get("/jobs/{job_id}")
async def get_job(job_id: str):
    """Get specific job details"""
    job = get_job_by_id(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    
    return job  # Job is already a dictionary in the in-memory system


@app.post("/jobs/{job_id}/cancel")
async def cancel_job_endpoint(job_id: str):
    """Cancel a running job"""
    if not get_job_by_id(job_id):
        raise HTTPException(status_code=404, detail="Job not found")
    
    success = cancel_job(job_id)
    if success:
        return {"message": "Job cancelled successfully"}
    else:
        raise HTTPException(status_code=500, detail="Failed to cancel job")


@app.get("/jobs/{job_id}/logs")
async def get_job_logs(job_id: str, tail: int = 500):
    """Get logs for a specific job"""
    job = get_job_by_id(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    
    # Since we're using in-memory job management, job logs are printed to console
    # For now, return an empty lines array as the logs are handled by console output
    tail = max(1, min(tail, 5000))
    return {"job_id": job_id, "lines": []}


@app.get("/jobs/{job_id}/screenshots")
async def get_job_screenshots_endpoint(job_id: str):
    """Get screenshots for a specific job"""
    job = get_job_by_id(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    
    screenshots = get_job_screenshots(job_id)
    return screenshots


# Monitoring endpoint for automation progress page
@app.get("/monitor/{job_id}")
async def get_monitor_data(job_id: str):
    """Get job monitoring data for the automation monitor page"""
    job = get_job_by_id(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    
    # Return job data with any logs or additional monitoring info
    return {
        "job": job,
        "logs": [],  # Logs are handled via WebSocket
        "screenshots": get_job_screenshots(job_id) if job else []
    }


# Excel Export Endpoint
@app.get("/leads/export/excel")
async def export_leads_excel(
    status: Optional[str] = None,
    industry: Optional[str] = None,
    location: Optional[str] = None,
    search: Optional[str] = None,
    has_website: Optional[bool] = None,
    min_rating: Optional[float] = None,
    min_reviews: Optional[int] = None,
    min_pagespeed_mobile: Optional[int] = None,
    max_pagespeed_mobile: Optional[int] = None,
    min_pagespeed_desktop: Optional[int] = None,
    max_pagespeed_desktop: Optional[int] = None,
    pagespeed_tested: Optional[bool] = None
):
    """
    Export filtered leads to Excel file.
    All query parameters are optional and will filter the export.
    """
    from excel_exporter import export_leads_to_excel
    from fastapi.responses import Response
    
    try:
        # Generate Excel file with filters
        excel_content = export_leads_to_excel(
            status=status,
            industry=industry,
            location=location,
            search_query=search,
            has_website=has_website,
            min_rating=min_rating,
            min_reviews=min_reviews,
            min_pagespeed_mobile=min_pagespeed_mobile,
            max_pagespeed_mobile=max_pagespeed_mobile,
            min_pagespeed_desktop=min_pagespeed_desktop,
            max_pagespeed_desktop=max_pagespeed_desktop,
            pagespeed_tested=pagespeed_tested
        )
        
        # Generate filename with timestamp
        filename = f"leads_export_{datetime.now().strftime('%Y%m%d_%H%M%S')}.xlsx"
        
        # Return Excel file as response
        return Response(
            content=excel_content,
            media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            headers={
                "Content-Disposition": f"attachment; filename={filename}",
                "Content-Type": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            }
        )
    except Exception as e:
        logger.error(f"Excel export error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Export failed: {str(e)}")


# Lead Management Endpoints
@app.get("/leads", response_model=list[LeadResponse])
async def get_leads(
    status: Optional[str] = None,
    industry: Optional[str] = None,
    location: Optional[str] = None,
    has_website: Optional[bool] = None,
    min_pagespeed_mobile: Optional[int] = None,
    max_pagespeed_mobile: Optional[int] = None,
    min_pagespeed_desktop: Optional[int] = None,
    max_pagespeed_desktop: Optional[int] = None,
    pagespeed_tested: Optional[bool] = None
):
    """Get all leads with optional filtering"""
    db = SessionLocal()
    try:
        query = db.query(Lead).options(
            selectinload(Lead.timeline_entries),
            selectinload(Lead.sales_pitch)
        )
        
        # Apply filters
        if status:
            query = query.filter(Lead.status == status)
        if industry:
            query = query.filter(Lead.industry == industry)
        if location:
            query = query.filter(Lead.location == location)
        if has_website is not None:
            if has_website:
                query = query.filter(Lead.website_url.isnot(None))
            else:
                query = query.filter(Lead.website_url.is_(None))
        
        # PageSpeed filters
        if min_pagespeed_mobile is not None:
            query = query.filter(Lead.pagespeed_mobile_score >= min_pagespeed_mobile)
        if max_pagespeed_mobile is not None:
            query = query.filter(Lead.pagespeed_mobile_score <= max_pagespeed_mobile)
        if min_pagespeed_desktop is not None:
            query = query.filter(Lead.pagespeed_desktop_score >= min_pagespeed_desktop)
        if max_pagespeed_desktop is not None:
            query = query.filter(Lead.pagespeed_desktop_score <= max_pagespeed_desktop)
        if pagespeed_tested is not None:
            if pagespeed_tested:
                query = query.filter(Lead.pagespeed_tested_at.isnot(None))
            else:
                query = query.filter(Lead.pagespeed_tested_at.is_(None))
        
        leads = query.order_by(Lead.created_at.desc()).all()
        return [LeadResponse.from_orm(lead) for lead in leads]
    finally:
        db.close()


@app.get("/leads/{lead_id}", response_model=LeadResponse)
async def get_lead(lead_id: str):
    """Get specific lead"""
    lead = get_lead_by_id(lead_id)
    if not lead:
        raise HTTPException(status_code=404, detail="Lead not found")
    return LeadResponse.from_orm(lead)


@app.delete("/leads/{lead_id}")
async def delete_lead(lead_id: str):
    """Delete a specific lead"""
    success = delete_lead_by_id(lead_id)
    if success:
        return {"message": "Lead deleted successfully"}
    else:
        raise HTTPException(status_code=404, detail="Lead not found")


@app.put("/leads/{lead_id}", response_model=LeadResponse)
async def update_lead_endpoint(lead_id: str, update_data: LeadUpdate):
    """Update a lead"""
    lead = update_lead(lead_id, update_data)
    if not lead:
        raise HTTPException(status_code=404, detail="Lead not found")
    return lead


@app.put("/leads/{lead_id}/timeline/{entry_id}", response_model=LeadResponse)
async def update_timeline_entry(lead_id: str, entry_id: str, update_data: LeadTimelineEntryUpdate):
    """Update a timeline entry"""
    lead = update_lead_timeline_entry(lead_id, entry_id, update_data)
    if not lead:
        raise HTTPException(status_code=404, detail="Lead or timeline entry not found")
    return lead


# Admin Endpoints
@app.delete("/admin/leads")
async def delete_all_leads_endpoint():
    """Delete all leads"""
    success = delete_all_leads()
    if success:
        return {"message": "All leads deleted successfully"}
    else:
        raise HTTPException(status_code=500, detail="Failed to delete leads")


@app.delete("/admin/leads/mock")
async def delete_mock_leads_endpoint():
    """Delete mock leads"""
    success = delete_mock_leads()
    if success:
        return {"message": "Mock leads deleted successfully"}
    else:
        raise HTTPException(status_code=500, detail="Failed to delete mock leads")


# File serving endpoints
@app.get("/logs")
async def get_logs():
    """Stream server logs"""
    log_file = Path("server.log")
    if not log_file.exists():
        raise HTTPException(status_code=404, detail="Log file not found")
    
    def read_log():
        with open(log_file, 'r') as f:
            for line in f:
                yield line
    
    return StreamingResponse(read_log(), media_type="text/plain")


@app.get("/screenshots/{filename}")
async def serve_screenshot(filename: str):
    """Serve screenshot files"""
    screenshot_path = Path("screenshots") / filename
    if not screenshot_path.exists():
        raise HTTPException(status_code=404, detail="Screenshot not found")
    
    return FileResponse(screenshot_path)


# WebSocket endpoints
@app.websocket("/ws/jobs/{job_id}")
async def websocket_job_updates(websocket: WebSocket, job_id: str):
    """WebSocket for job updates"""
    await job_websocket_manager.handle_job_websocket(websocket, job_id)


@app.websocket("/ws/logs")
async def websocket_logs(websocket: WebSocket):
    """WebSocket for log streaming"""
    await log_websocket_manager.handle_log_websocket(websocket)


@app.websocket("/ws/pagespeed")
async def websocket_pagespeed(websocket: WebSocket):
    """WebSocket for PageSpeed updates"""
    await pagespeed_websocket_manager.handle_pagespeed_websocket(websocket)


# Container management (placeholder endpoints)
@app.get("/containers/status")
async def get_container_status():
    """Get container status"""
    return {"status": "running", "containers": 1}


@app.post("/containers/scale")
async def scale_containers(target_count: int):
    """Scale containers"""
    return {"message": f"Scaling to {target_count} containers", "current": 1}


# Parallel execution endpoints
from pydantic import BaseModel

class ParallelJobRequest(BaseModel):
    industries: List[str]
    locations: List[str]
    limit: int = 50
    min_rating: float = 0.0
    min_reviews: int = 0
    requires_website: Optional[bool] = None
    recent_review_months: Optional[int] = 24
    enable_pagespeed: bool = False
    max_pagespeed_score: Optional[int] = None  # Maximum acceptable PageSpeed score (required if enable_pagespeed is True)

@app.post("/jobs/parallel", response_model=Dict[str, Any])
async def create_parallel_jobs(
    job_request: ParallelJobRequest,
    background_tasks: BackgroundTasks = None,
    request: Request = None
):
    """Create parallel jobs for multiple industry-location combinations"""
    try:
        # Extract values from the request object
        industries = job_request.industries
        locations = job_request.locations
        limit = job_request.limit
        min_rating = job_request.min_rating
        min_reviews = job_request.min_reviews
        requires_website = job_request.requires_website
        recent_review_months = job_request.recent_review_months
        enable_pagespeed = job_request.enable_pagespeed
        max_pagespeed_score = job_request.max_pagespeed_score
        
        # Validate PageSpeed parameters
        if enable_pagespeed and max_pagespeed_score is None:
            # Default to 50 if not provided but PageSpeed is enabled
            max_pagespeed_score = 50
            print(f"⚠️ PageSpeed enabled but no max_pagespeed_score provided, defaulting to 50")
        
        # Log the parameters received
        print(f"🔍 Parallel job request received:")
        print(f"    Industries: {industries}")
        print(f"    Locations: {locations}")
        print(f"    requires_website: {requires_website}")
        print(f"    enable_pagespeed: {enable_pagespeed} (from Pydantic model)")
        print(f"    max_pagespeed_score: {max_pagespeed_score}")
        print(f"    limit: {limit}, min_rating: {min_rating}, min_reviews: {min_reviews}")
        
        # Check Selenium Grid status
        grid_status = parallel_executor.get_grid_status()
        # For single Chrome container, just check if we can connect
        if not grid_status.get("ready") and grid_status.get("nodes", 0) == 0:
            raise HTTPException(
                status_code=503, 
                detail=f"Selenium not available: {grid_status.get('error', 'No browser nodes available')}"
            )
        
        # Calculate required nodes
        total_jobs = len(industries) * len(locations)
        available_nodes = grid_status.get("nodes", 0)
        
        # Note: We're using a fixed Selenium container, not dynamically scaling
        # The single container can handle multiple sessions (SE_NODE_MAX_SESSIONS=3)
        
        # Create job matrix
        base_params = {
            "limit": limit,
            "min_rating": min_rating,
            "min_reviews": min_reviews,
            "requires_website": requires_website,
            "recent_review_months": recent_review_months,
            "enable_pagespeed": enable_pagespeed,
            "max_pagespeed_score": max_pagespeed_score
        }
        
        job_matrix = parallel_executor.create_multi_location_jobs(
            industries, locations, base_params
        )
        
        # Execute in background
        if background_tasks:
            background_tasks.add_task(
                parallel_executor.execute_parallel_jobs,
                job_matrix
            )
        
        return {
            "parent_job_id": job_matrix["parent_id"],
            "child_job_ids": job_matrix["child_ids"],
            "total_searches": total_jobs,
            "industries": industries,
            "locations": locations,
            "grid_nodes": grid_status.get("nodes", 0),
            "message": f"Started {total_jobs} parallel searches"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create parallel jobs: {str(e)}")


@app.get("/jobs/parallel/{parent_job_id}/status")
async def get_parallel_job_status(parent_job_id: str):
    """Get status of parallel job execution"""
    parent_job = get_job_by_id(parent_job_id)
    if not parent_job:
        raise HTTPException(status_code=404, detail="Parent job not found")
    
    if parent_job.get("type") != "parent":
        raise HTTPException(status_code=400, detail="Not a parent job")
    
    # Get child job statuses
    child_statuses = []
    for child_id in parent_job.get("child_jobs", []):
        child_job = get_job_by_id(child_id)
        if child_job:
            child_statuses.append({
                "id": child_id,
                "industry": child_job.get("industry"),
                "location": child_job.get("location"),
                "status": child_job.get("status"),
                "processed": child_job.get("processed", 0),
                "total": child_job.get("total", 0)
            })
    
    return {
        "parent_job": parent_job,
        "child_jobs": child_statuses,
        "progress": {
            "completed": parent_job.get("completed_combinations", 0),
            "total": parent_job.get("total_combinations", 0),
            "percentage": round(
                (parent_job.get("completed_combinations", 0) / 
                 max(parent_job.get("total_combinations", 1), 1)) * 100,
                1
            )
        }
    }


@app.get("/containers/status")
async def get_container_infrastructure_status():
    """Get container infrastructure and resource status"""
    from dynamic_container_manager import container_manager
    return container_manager.get_container_stats()


@app.post("/containers/cleanup")
async def cleanup_orphaned_containers():
    """Clean up orphaned containers and free resources"""
    from dynamic_container_manager import container_manager
    try:
        container_manager.cleanup_orphaned_containers()
        return {"message": "Cleanup completed successfully", "success": True}
    except Exception as e:
        return {"message": f"Cleanup failed: {str(e)}", "success": False}


@app.get("/grid/status")
async def get_selenium_grid_status():
    """Get container infrastructure status (legacy endpoint)"""
    return await get_container_infrastructure_status()


@app.post("/grid/scale")
async def scale_selenium_grid(target_nodes: int):
    """This endpoint is deprecated - containers now scale automatically"""
    return {
        "message": "Containers now scale automatically based on demand and system resources",
        "success": True,
        "mode": "automatic",
        "max_containers": os.getenv('MAX_SELENIUM_CONTAINERS', '10')
    }


# Analytics Endpoints
@app.get("/analytics/overview")
async def get_analytics_overview():
    """Get conversion overview metrics"""
    try:
        db = SessionLocal()
        overview = AnalyticsEngine.get_conversion_overview(db)
        db.close()
        return overview
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get analytics overview: {str(e)}")


@app.get("/analytics/segments")
async def get_top_segments(limit: int = 10):
    """Get top converting segments"""
    try:
        db = SessionLocal()
        segments = AnalyticsEngine.get_top_converting_segments(db, limit)
        db.close()
        return segments
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get segments: {str(e)}")


@app.get("/analytics/timeline")
async def get_conversion_timeline(days: int = 30):
    """Get conversion timeline data"""
    try:
        db = SessionLocal()
        timeline = AnalyticsEngine.get_conversion_timeline(db, days)
        db.close()
        return {"timeline": timeline}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get timeline: {str(e)}")


@app.get("/analytics/insights")
async def get_insights():
    """Get actionable insights"""
    try:
        db = SessionLocal()
        insights = AnalyticsEngine.get_actionable_insights(db)
        db.close()
        return {"insights": insights}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get insights: {str(e)}")


# PageSpeed Insights Endpoints
@app.post("/leads/{lead_id}/pagespeed")
async def test_lead_pagespeed(lead_id: str, background_tasks: BackgroundTasks):
    """Test PageSpeed for a single lead"""
    from pagespeed_service import PageSpeedService
    
    db = SessionLocal()
    try:
        lead = db.query(Lead).filter(Lead.id == lead_id).first()
        if not lead:
            raise HTTPException(status_code=404, detail="Lead not found")
        
        if not lead.website_url:
            raise HTTPException(status_code=400, detail="Lead has no website")
        
        print(f"Starting PageSpeed test for {lead.business_name} - {lead.website_url}")
        
        # Run PageSpeed test in background
        service = PageSpeedService()
        
        # Add to background task to run async
        background_tasks.add_task(
            service.test_lead_website,
            lead_id
        )
        
        return {"message": f"PageSpeed test started for {lead.business_name}. Results will appear in 1-2 minutes."}
    except Exception as e:
        print(f"Error in PageSpeed test: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()


@app.post("/leads/pagespeed/bulk")
async def test_bulk_pagespeed(lead_ids: List[str], background_tasks: BackgroundTasks):
    """Test PageSpeed for multiple leads"""
    from pagespeed_service import PageSpeedService
    
    db = SessionLocal()
    try:
        leads = db.query(Lead).filter(Lead.id.in_(lead_ids)).all()
        if not leads:
            raise HTTPException(status_code=404, detail="No leads found")
        
        # Filter leads with websites
        leads_with_websites = [l for l in leads if l.website_url]
        if not leads_with_websites:
            raise HTTPException(status_code=400, detail="No leads have websites")
        
        # Run PageSpeed tests in background
        service = PageSpeedService()
        background_tasks.add_task(
            service.test_multiple_leads_async,
            [(l.id, l.website_url) for l in leads_with_websites]
        )
        
        return {
            "message": f"PageSpeed tests started for {len(leads_with_websites)} leads",
            "lead_count": len(leads_with_websites)
        }
    finally:
        db.close()


@app.get("/leads/pagespeed/status")
async def get_pagespeed_status():
    """Get status of PageSpeed testing"""
    from pagespeed_service import PageSpeedService
    
    service = PageSpeedService()
    return service.get_testing_status()


@app.post("/jobs/{job_id}/pagespeed")
async def enable_job_pagespeed(job_id: str, enable: bool = True):
    """Enable/disable PageSpeed testing for a job"""
    job = get_job_by_id(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    
    # Store PageSpeed setting for job
    job['pagespeed_enabled'] = enable
    
    return {
        "job_id": job_id,
        "pagespeed_enabled": enable,
        "message": f"PageSpeed testing {'enabled' if enable else 'disabled'} for job"
    }


# Conversion Scoring Endpoints
@app.post("/conversion/train", response_model=ConversionModelResponse)
async def train_conversion_model(background_tasks: BackgroundTasks):
    """Train a new conversion scoring model based on historical data"""
    from conversion_scoring_service import ConversionScoringService
    
    db = SessionLocal()
    try:
        service = ConversionScoringService(db)
        model = service.train_model()
        
        if not model:
            raise HTTPException(
                status_code=400, 
                detail="Not enough data to train model. Need at least 100 samples with conversions."
            )
        
        # Schedule background recalculation of all scores with new model
        background_tasks.add_task(service.calculate_all_scores)
        
        return ConversionModelResponse(
            model_version=model.model_version,
            accuracy=model.model_accuracy,
            f1_score=model.f1_score,
            precision=model.precision_score,
            recall=model.recall_score,
            training_samples=model.training_samples,
            baseline_conversion_rate=model.baseline_conversion_rate,
            created_at=model.created_at,
            is_active=model.is_active
        )
    except Exception as e:
        logger.error(f"Error training conversion model: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()


@app.post("/conversion/calculate", response_model=ConversionScoringResponse)
async def calculate_conversion_scores(background_tasks: BackgroundTasks):
    """Calculate conversion scores for all leads"""
    from conversion_scoring_service import ConversionScoringService
    
    db = SessionLocal()
    try:
        service = ConversionScoringService(db)
        
        # Run calculation in background
        background_tasks.add_task(service.calculate_all_scores)
        
        # Get current stats
        total_leads = db.query(func.count(Lead.id)).scalar()
        
        return ConversionScoringResponse(
            status="started",
            total_leads=total_leads,
            message="Conversion scoring started in background"
        )
    except Exception as e:
        logger.error(f"Error calculating conversion scores: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()


@app.get("/conversion/stats", response_model=ConversionModelResponse)
async def get_conversion_model_stats():
    """Get statistics about the current conversion model"""
    from conversion_scoring_service import ConversionScoringService
    
    db = SessionLocal()
    try:
        service = ConversionScoringService(db)
        stats = service.get_model_stats()
        
        if 'status' in stats and stats['status'] == 'No model trained':
            raise HTTPException(status_code=404, detail="No conversion model has been trained yet")
        
        return ConversionModelResponse(
            model_version=stats['model_version'],
            accuracy=stats['accuracy'],
            f1_score=stats['f1_score'],
            precision=stats['precision'],
            recall=stats['recall'],
            training_samples=stats['training_samples'],
            baseline_conversion_rate=stats['baseline_conversion_rate'],
            created_at=stats['created_at'],
            is_active=True
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting conversion model stats: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()


@app.get("/leads/top-converting")
async def get_top_converting_leads(
    limit: int = 20,
    min_score: float = 0.5
):
    """Get leads with highest conversion probability"""
    from conversion_scoring_service import ConversionScoringService
    
    db = SessionLocal()
    try:
        # Get leads sorted by conversion score
        leads = db.query(Lead).filter(
            Lead.conversion_score.isnot(None),
            Lead.conversion_score >= min_score,
            Lead.status.notin_([LeadStatus.converted, LeadStatus.doNotCall])
        ).order_by(Lead.conversion_score.desc()).limit(limit).all()
        
        return [LeadResponse.from_orm(lead) for lead in leads]
    except Exception as e:
        logger.error(f"Error getting top converting leads: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()


# Sales Pitch Management Endpoints
@app.get("/sales-pitches", response_model=List[SalesPitchResponse])
def get_sales_pitches(active_only: bool = True):
    """Get all sales pitches"""
    db = SessionLocal()
    try:
        query = db.query(SalesPitch)
        if active_only:
            query = query.filter(SalesPitch.is_active == True)
        pitches = query.all()
        return pitches
    finally:
        db.close()


@app.post("/sales-pitches", response_model=SalesPitchResponse)
def create_sales_pitch(pitch: SalesPitchCreate):
    """Create a new sales pitch"""
    db = SessionLocal()
    try:
        db_pitch = SalesPitch(**pitch.dict())
        db.add(db_pitch)
        db.commit()
        db.refresh(db_pitch)
        return db_pitch
    finally:
        db.close()


@app.put("/sales-pitches/{pitch_id}", response_model=SalesPitchResponse)
def update_sales_pitch(pitch_id: str, pitch_update: SalesPitchUpdate):
    """Update an existing sales pitch"""
    db = SessionLocal()
    try:
        db_pitch = db.query(SalesPitch).filter(SalesPitch.id == pitch_id).first()
        if not db_pitch:
            raise HTTPException(status_code=404, detail="Sales pitch not found")
        
        update_data = pitch_update.dict(exclude_unset=True)
        for field, value in update_data.items():
            setattr(db_pitch, field, value)
        
        db_pitch.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(db_pitch)
        return db_pitch
    finally:
        db.close()


@app.delete("/sales-pitches/{pitch_id}")
def delete_sales_pitch(pitch_id: str):
    """Delete a sales pitch (soft delete by setting inactive)"""
    db = SessionLocal()
    try:
        db_pitch = db.query(SalesPitch).filter(SalesPitch.id == pitch_id).first()
        if not db_pitch:
            raise HTTPException(status_code=404, detail="Sales pitch not found")
        
        # Check if there are at least 2 active pitches before deactivating
        active_count = db.query(SalesPitch).filter(SalesPitch.is_active == True).count()
        if active_count <= 2 and db_pitch.is_active:
            raise HTTPException(
                status_code=400, 
                detail="Cannot deactivate pitch. At least 2 active pitches are required."
            )
        
        db_pitch.is_active = False
        db_pitch.updated_at = datetime.utcnow()
        db.commit()
        return {"status": "success", "message": "Sales pitch deactivated"}
    finally:
        db.close()


@app.post("/leads/{lead_id}/assign-pitch")
def assign_pitch_to_lead(lead_id: str, request: LeadUpdateRequest):
    """Assign a sales pitch to a lead"""
    db = SessionLocal()
    try:
        lead = db.query(Lead).filter(Lead.id == lead_id).first()
        if not lead:
            raise HTTPException(status_code=404, detail="Lead not found")
        
        pitch_id = request.sales_pitch_id
        if not pitch_id:
            raise HTTPException(status_code=400, detail="sales_pitch_id is required")
            
        pitch = db.query(SalesPitch).filter(
            SalesPitch.id == pitch_id,
            SalesPitch.is_active == True
        ).first()
        if not pitch:
            raise HTTPException(status_code=404, detail="Sales pitch not found or inactive")
        
        lead.sales_pitch_id = pitch_id
        
        # Track the pitch attempt
        pitch.attempts += 1
        
        # Add timeline entry
        timeline_entry = LeadTimelineEntry(
            id=str(uuid.uuid4()),
            lead_id=lead_id,
            type=TimelineEntryType.NOTE,
            title="Sales Pitch Assigned",
            description=f"Assigned pitch: {pitch.name}",
            created_at=datetime.utcnow()
        )
        db.add(timeline_entry)
        
        db.commit()
        db.refresh(lead)
        return LeadResponse.from_orm(lead)
    finally:
        db.close()


@app.get("/sales-pitches/analytics")
def get_pitch_analytics():
    """Get A/B testing analytics for all sales pitches"""
    db = SessionLocal()
    try:
        pitches = db.query(SalesPitch).all()
        
        analytics = []
        for pitch in pitches:
            # Count conversions
            converted_leads = db.query(Lead).filter(
                Lead.sales_pitch_id == pitch.id,
                Lead.status == LeadStatus.converted
            ).count()
            
            # Update pitch conversion metrics
            if pitch.attempts > 0:
                pitch.conversions = converted_leads
                pitch.conversion_rate = (converted_leads / pitch.attempts) * 100
            
            analytics.append({
                "id": pitch.id,
                "name": pitch.name,
                "attempts": pitch.attempts,
                "conversions": pitch.conversions,
                "conversion_rate": pitch.conversion_rate,
                "is_active": pitch.is_active
            })
        
        db.commit()
        
        # Calculate statistical significance if we have 2 active pitches
        active_pitches = [p for p in analytics if p["is_active"]]
        if len(active_pitches) >= 2:
            # Simple chi-square test placeholder
            total_attempts = sum(p["attempts"] for p in active_pitches)
            total_conversions = sum(p["conversions"] for p in active_pitches)
            
            if total_attempts > 0:
                baseline_rate = total_conversions / total_attempts
                for pitch in analytics:
                    if pitch["attempts"] > 0:
                        expected = pitch["attempts"] * baseline_rate
                        pitch["expected_conversions"] = expected
                        pitch["performance"] = "above" if pitch["conversions"] > expected else "below"
        
        return {
            "pitches": analytics,
            "total_attempts": sum(p["attempts"] for p in analytics),
            "total_conversions": sum(p["conversions"] for p in analytics),
            "overall_conversion_rate": (sum(p["conversions"] for p in analytics) / 
                                       max(sum(p["attempts"] for p in analytics), 1)) * 100
        }
    finally:
        db.close()


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)