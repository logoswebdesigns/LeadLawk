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
from datetime import datetime, timezone, timedelta

from fastapi import FastAPI, HTTPException, BackgroundTasks, WebSocket, WebSocketDisconnect, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import StreamingResponse, FileResponse
from fastapi.encoders import jsonable_encoder
from logging.handlers import RotatingFileHandler
from sqlalchemy import func

# Local imports
from database import SessionLocal, init_db
from sqlalchemy.orm import selectinload
from models import Lead, LeadStatus, SalesPitch, LeadTimelineEntry, TimelineEntryType, EmailTemplate
from blacklist_manager import BlacklistManager, initialize_blacklist
from schemas import (BrowserAutomationRequest, JobResponse, LeadResponse, LeadUpdate, 
                    LeadTimelineEntryUpdate, LeadTimelineEntryCreate, ConversionModelResponse, ConversionScoringResponse,
                    SalesPitchResponse, SalesPitchCreate, SalesPitchUpdate, LeadUpdateRequest,
                    EmailTemplateResponse, EmailTemplateCreate, EmailTemplateUpdate, LeadStatisticsResponse)

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


# Simple in-memory cache for statistics
statistics_cache = {
    "data": None,
    "timestamp": None,
    "ttl_seconds": 30  # Cache for 30 seconds
}

def invalidate_statistics_cache():
    """Invalidate the statistics cache when leads are modified"""
    statistics_cache["data"] = None
    statistics_cache["timestamp"] = None
    logger.info("Statistics cache invalidated")


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
@app.get("/leads/called-today")
async def get_leads_called_today(
    page: int = 1,
    per_page: int = 20
):
    """Get leads that were called today - optimized with pagination and efficient queries"""
    db = SessionLocal()
    try:
        from datetime import date
        from sqlalchemy import func, and_, or_, text
        import time
        
        start_time = time.time()
        
        # Use timezone-aware datetime
        today_start = datetime.combine(date.today(), datetime.min.time(), tzinfo=timezone.utc)
        today_end = datetime.combine(date.today(), datetime.max.time(), tzinfo=timezone.utc)
        
        # Optimized query using EXISTS subquery for better performance
        # This avoids the IN clause which can be slow with large datasets
        base_query = db.query(Lead).filter(
            or_(
                # Has phone call today
                db.query(LeadTimelineEntry).filter(
                    and_(
                        LeadTimelineEntry.lead_id == Lead.id,
                        LeadTimelineEntry.type == 'phone_call',
                        LeadTimelineEntry.created_at >= today_start,
                        LeadTimelineEntry.created_at <= today_end
                    )
                ).exists(),
                # Has status change to called/interested/converted today
                db.query(LeadTimelineEntry).filter(
                    and_(
                        LeadTimelineEntry.lead_id == Lead.id,
                        LeadTimelineEntry.type == 'status_change',
                        LeadTimelineEntry.new_status.in_(['called', 'interested', 'converted']),
                        LeadTimelineEntry.created_at >= today_start,
                        LeadTimelineEntry.created_at <= today_end
                    )
                ).exists()
            )
        )
        
        # Count total for pagination
        total = base_query.count()
        
        # Apply pagination
        offset = (page - 1) * per_page
        leads = base_query.order_by(Lead.updated_at.desc()).offset(offset).limit(per_page).all()
        
        query_time = time.time() - start_time
        logger.info(f"Called-today query took {query_time:.3f} seconds for {len(leads)} leads")
        
        return {
            "leads": [LeadResponse.from_orm(lead) for lead in leads],
            "total": total,
            "page": page,
            "per_page": per_page,
            "total_pages": (total + per_page - 1) // per_page,
            "query_time_ms": round(query_time * 1000, 2)
        }
    finally:
        db.close()


@app.get("/leads")
async def get_leads(
    page: int = 1,
    per_page: int = 20,
    status: Optional[str] = None,
    industry: Optional[str] = None,
    location: Optional[str] = None,
    has_website: Optional[bool] = None,
    min_pagespeed_mobile: Optional[int] = None,
    max_pagespeed_mobile: Optional[int] = None,
    min_pagespeed_desktop: Optional[int] = None,
    max_pagespeed_desktop: Optional[int] = None,
    pagespeed_tested: Optional[bool] = None,
    sort_by: str = "created_at",
    sort_ascending: bool = False,
    search: Optional[str] = None,
    candidates_only: Optional[bool] = None
):
    """Get paginated leads with optional filtering and sorting"""
    # Log sorting parameters
    logger.info(f"🔄 BACKEND SORT: sort_by={sort_by}, ascending={sort_ascending}")
    logger.info(f"📊 BACKEND FILTERS: status={status}, search={search}, candidates_only={candidates_only}")
    
    db = SessionLocal()
    try:
        # Limit per_page to prevent abuse
        per_page = min(per_page, 100)
        page = max(page, 1)
        
        query = db.query(Lead).options(
            selectinload(Lead.timeline_entries),
            selectinload(Lead.sales_pitch)
        )
        
        # Apply filters
        if status:
            # Map Flutter's 'new_' to database 'new' (new is reserved in Dart)
            db_status = 'new' if status == 'new_' else status
            query = query.filter(Lead.status == db_status)
        if industry:
            query = query.filter(Lead.industry == industry)
        if location:
            query = query.filter(Lead.location == location)
        if has_website is not None:
            if has_website:
                query = query.filter(Lead.website_url.isnot(None))
            else:
                query = query.filter(Lead.website_url.is_(None))
        
        # Search filter
        if search:
            search_pattern = f"%{search}%"
            query = query.filter(
                (Lead.business_name.ilike(search_pattern)) |
                (Lead.phone.ilike(search_pattern)) |
                (Lead.location.ilike(search_pattern))
            )
        
        # Candidates only filter
        if candidates_only:
            query = query.filter(Lead.is_candidate == True)
        
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
        
        # Apply sorting with proper null handling
        from sqlalchemy import nulls_last, nulls_first, desc, asc
        
        # Map sort fields to database columns
        sort_field_map = {
            "created_at": Lead.created_at,
            "business_name": Lead.business_name,
            "rating": Lead.rating,
            "review_count": Lead.review_count,
            "pagespeed_mobile_score": Lead.pagespeed_mobile_score,
            "pagespeed_desktop_score": Lead.pagespeed_desktop_score,
            "desktop_performance_score": Lead.pagespeed_desktop_score,  # Alias for API compatibility
            "conversion_score": Lead.conversion_score,
        }
        
        # Get the sort column
        sort_column = sort_field_map.get(sort_by, Lead.created_at)
        
        # For nullable fields (rating, review_count, pagespeed scores, conversion_score),
        # we want to show non-null values first, then nulls at the end
        nullable_fields = ["rating", "review_count", "pagespeed_mobile_score", 
                          "pagespeed_desktop_score", "desktop_performance_score", "conversion_score"]
        
        # Log which sorting strategy is being used
        if sort_by in nullable_fields:
            logger.info(f"🔄 BACKEND: Sorting by {sort_by} (nullable field) - non-null values first, {'ascending' if sort_ascending else 'descending'}")
        else:
            logger.info(f"🔄 BACKEND: Sorting by {sort_by} (non-nullable field) - {'ascending' if sort_ascending else 'descending'}")
        
        if sort_by in nullable_fields:
            # For nullable fields, always show non-null values first
            if sort_ascending:
                # Ascending: Show lowest non-null values first, then nulls
                query = query.order_by(nulls_last(asc(sort_column)))
            else:
                # Descending: Show highest non-null values first, then nulls
                query = query.order_by(nulls_last(desc(sort_column)))
        else:
            # For non-nullable fields, sort normally
            if sort_ascending:
                query = query.order_by(asc(sort_column))
            else:
                query = query.order_by(desc(sort_column))
        
        # Always return paginated response
        # Get total count for pagination
        total = query.count()
        
        # Calculate pagination
        offset = (page - 1) * per_page
        total_pages = (total + per_page - 1) // per_page
        
        # Get paginated results
        leads = query.offset(offset).limit(per_page).all()
        
        # Return paginated response
        return {
            "items": [LeadResponse.from_orm(lead) for lead in leads],
            "total": total,
            "page": page,
            "per_page": per_page,
            "total_pages": total_pages,
            "has_next": page < total_pages,
            "has_prev": page > 1
        }
    finally:
        db.close()


@app.get("/leads/statistics/all", response_model=LeadStatisticsResponse)
async def get_lead_statistics():
    """Get overall lead statistics by status - optimized version with caching"""
    
    # Check cache first
    now = datetime.now(timezone.utc)
    if (statistics_cache["data"] is not None and 
        statistics_cache["timestamp"] is not None and
        (now - statistics_cache["timestamp"]).total_seconds() < statistics_cache["ttl_seconds"]):
        logger.info("Returning cached statistics")
        return statistics_cache["data"]
    
    logger.info("Cache miss, fetching fresh statistics")
    db = SessionLocal()
    try:
        # Use a single query with GROUP BY for better performance
        from sqlalchemy import func
        
        start_time = time.time()
        
        # Get counts grouped by status in a single query
        status_counts = db.query(
            Lead.status,
            func.count(Lead.id).label('count')
        ).group_by(Lead.status).all()
        
        query_time = time.time() - start_time
        logger.info(f"Statistics query took {query_time:.3f} seconds")
        
        # Build the by_status dictionary
        by_status = {}
        total = 0
        for status_row in status_counts:
            by_status[status_row.status.value] = status_row.count
            total += status_row.count
        
        # Fill in any missing statuses with 0
        for status in LeadStatus:
            if status.value not in by_status:
                by_status[status.value] = 0
        
        # Calculate conversion rate
        converted = by_status.get(LeadStatus.converted.value, 0)
        conversion_rate = (converted / total * 100) if total > 0 else 0.0
        
        response = LeadStatisticsResponse(
            total=total,
            by_status=by_status,
            conversion_rate=conversion_rate
        )
        
        # Update cache
        statistics_cache["data"] = response
        statistics_cache["timestamp"] = now
        
        return response
    finally:
        db.close()


# Cache for today's statistics with TTL
today_stats_cache = {
    "data": None,
    "timestamp": None,
    "date": None,
    "ttl_seconds": 60  # 1 minute cache for today stats
}

@app.get("/leads/statistics/today", response_model=dict)
async def get_today_statistics():
    """Get statistics for today's activities - optimized with caching and efficient queries"""
    from datetime import date
    from sqlalchemy import func, and_, or_, text
    
    # Check cache first
    now = datetime.now(timezone.utc)
    today_date = date.today()
    
    if (today_stats_cache["data"] is not None and 
        today_stats_cache["date"] == today_date and
        today_stats_cache["timestamp"] is not None and
        (now - today_stats_cache["timestamp"]).total_seconds() < today_stats_cache["ttl_seconds"]):
        logger.info("Returning cached today's statistics")
        return today_stats_cache["data"]
    
    logger.info("Fetching fresh today's statistics")
    db = SessionLocal()
    try:
        import time
        start_time = time.time()
        
        # Use timezone-aware datetime for consistency
        today_start = datetime.combine(today_date, datetime.min.time(), tzinfo=timezone.utc)
        today_end = datetime.combine(today_date, datetime.max.time(), tzinfo=timezone.utc)
        
        # Single optimized query using UNION to get all call-related activities
        # This query leverages indexes on (type, created_at) and (new_status, created_at)
        calls_query = text("""
            SELECT COUNT(DISTINCT lead_id) as count
            FROM (
                SELECT lead_id
                FROM lead_timeline_entries
                WHERE type = 'phone_call'
                  AND created_at >= :today_start
                  AND created_at <= :today_end
                
                UNION
                
                SELECT lead_id
                FROM lead_timeline_entries
                WHERE type = 'status_change'
                  AND new_status IN ('called', 'interested', 'converted')
                  AND created_at >= :today_start
                  AND created_at <= :today_end
            ) as today_calls
        """)
        
        result = db.execute(calls_query, {
            'today_start': today_start,
            'today_end': today_end
        })
        today_calls = result.scalar() or 0
        
        # Separate optimized query for conversions
        conversions_query = text("""
            SELECT COUNT(DISTINCT lead_id) as count
            FROM lead_timeline_entries
            WHERE type = 'status_change'
              AND new_status = 'converted'
              AND created_at >= :today_start
              AND created_at <= :today_end
        """)
        
        result = db.execute(conversions_query, {
            'today_start': today_start,
            'today_end': today_end
        })
        conversions_today = result.scalar() or 0
        
        query_time = time.time() - start_time
        logger.info(f"Today's statistics query took {query_time:.3f} seconds")
        
        response = {
            "calls_today": today_calls,
            "conversions_today": conversions_today,
            "date": today_date.isoformat(),
            "query_time_ms": round(query_time * 1000, 2)
        }
        
        # Update cache
        today_stats_cache["data"] = response
        today_stats_cache["timestamp"] = now
        today_stats_cache["date"] = today_date
        
        return response
    finally:
        db.close()


@app.get("/leads/call-statistics")
async def get_call_statistics():
    """Get call statistics by date for calendar display"""
    from datetime import timedelta
    from sqlalchemy import func, text
    
    db = SessionLocal()
    try:
        # Get call statistics for the last 90 days
        end_date = datetime.now(timezone.utc).date()
        start_date = end_date - timedelta(days=90)
        
        # Query to get call counts grouped by date
        # Includes phone_call entries and status changes to called/interested/converted
        query = text("""
            SELECT 
                DATE(created_at) as call_date,
                COUNT(DISTINCT lead_id) as call_count
            FROM lead_timeline_entries
            WHERE (
                UPPER(type) = 'PHONE_CALL'
                OR (UPPER(type) = 'STATUS_CHANGE' AND UPPER(title) IN ('STATUS CHANGED TO CALLED', 'STATUS CHANGED TO INTERESTED', 'STATUS CHANGED TO CONVERTED'))
            )
            AND DATE(created_at) >= :start_date
            AND DATE(created_at) <= :end_date
            GROUP BY DATE(created_at)
            ORDER BY call_date DESC
        """)
        
        result = db.execute(query, {
            'start_date': start_date,
            'end_date': end_date
        })
        
        # Convert to dictionary with date strings as keys
        statistics = {}
        for row in result:
            # call_date is already a string from SQLite DATE() function
            date_str = row.call_date
            if date_str:
                statistics[date_str] = row.call_count
        
        return statistics
        
    except Exception as e:
        logger.error(f"Error fetching call statistics: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch call statistics: {str(e)}")
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


@app.post("/leads/{lead_id}/timeline", response_model=LeadResponse)
async def add_timeline_entry_endpoint(lead_id: str, entry_data: LeadTimelineEntryCreate):
    """Add a new timeline entry to a lead"""
    db = SessionLocal()
    try:
        lead = db.query(Lead).options(selectinload(Lead.timeline_entries)).filter(Lead.id == lead_id).first()
        if not lead:
            raise HTTPException(status_code=404, detail="Lead not found")
        
        # Create new timeline entry
        # Convert type to lowercase to match enum values
        try:
            entry_type = TimelineEntryType(entry_data.type.lower())
        except ValueError:
            # If the type doesn't match any enum value, default to NOTE
            print(f"Warning: Unknown timeline entry type '{entry_data.type}', defaulting to NOTE")
            entry_type = TimelineEntryType.NOTE
        
        entry = LeadTimelineEntry(
            id=str(uuid.uuid4()),
            lead_id=lead_id,
            type=entry_type,
            title=entry_data.title,
            description=entry_data.description,
            follow_up_date=entry_data.follow_up_date,
            created_at=datetime.utcnow()
        )
        
        db.add(entry)
        
        # If this is a status change, update the lead status
        if entry_data.type == "STATUS_CHANGE" and entry_data.metadata:
            new_status = entry_data.metadata.get("new_status")
            if new_status:
                lead.status = LeadStatus(new_status)
        
        # Update lead's updated_at timestamp
        lead.updated_at = datetime.utcnow()
        
        db.commit()
        db.refresh(lead)
        
        return LeadResponse.from_orm(lead)
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to add timeline entry: {str(e)}")
    finally:
        db.close()


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
    max_runtime_minutes: Optional[int] = 30  # Maximum runtime in minutes before job auto-stops (default 30 minutes)

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
        max_runtime_minutes = job_request.max_runtime_minutes
        
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
        print(f"    max_runtime_minutes: {max_runtime_minutes} (per child job)")
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
            "max_pagespeed_score": max_pagespeed_score,
            "max_runtime_minutes": max_runtime_minutes
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

@app.get("/leads/pagespeed/missing-count")
async def count_missing_pagespeed():
    """
    Count leads that have a website but no PageSpeed score.
    This excludes leads with pagespeed_error = true (those that already failed).
    """
    db = SessionLocal()
    try:
        # Count leads with website_url but no PageSpeed scores
        eligible_count = db.query(Lead).filter(
            Lead.website_url.isnot(None),
            Lead.website_url != '',
            Lead.pagespeed_mobile_score.is_(None),
            Lead.pagespeed_desktop_score.is_(None),
            # Exclude leads that already have errors
            (Lead.pagespeed_test_error.is_(None) | (Lead.pagespeed_test_error == False))
        ).count()
        
        # Also count leads with errors for reference
        error_count = db.query(Lead).filter(
            Lead.website_url.isnot(None),
            Lead.website_url != '',
            Lead.pagespeed_test_error == True
        ).count()
        
        # Count leads with scores
        scored_count = db.query(Lead).filter(
            Lead.website_url.isnot(None),
            Lead.website_url != '',
            (Lead.pagespeed_mobile_score.isnot(None) | Lead.pagespeed_desktop_score.isnot(None))
        ).count()
        
        return {
            "eligible_for_processing": eligible_count,
            "already_scored": scored_count,
            "previous_errors": error_count,
            "total_with_websites": eligible_count + scored_count + error_count
        }
    finally:
        db.close()

@app.post("/leads/pagespeed/process-missing")
async def process_missing_pagespeed(background_tasks: BackgroundTasks, limit: int = None):
    """
    Find and process leads that have a website but no PageSpeed score.
    This excludes leads with pagespeed_error = true (those that already failed).
    If no limit is specified, processes ALL eligible leads.
    """
    from pagespeed_service import PageSpeedService
    
    db = SessionLocal()
    try:
        # Find leads with website_url but no PageSpeed scores
        # Exclude leads that have pagespeed_error = true
        query = db.query(Lead).filter(
            Lead.website_url.isnot(None),
            Lead.website_url != '',
            Lead.pagespeed_mobile_score.is_(None),
            Lead.pagespeed_desktop_score.is_(None),
            # Exclude leads that already have errors
            (Lead.pagespeed_test_error.is_(None) | (Lead.pagespeed_test_error == False))
        )
        
        # Apply limit only if specified
        if limit:
            eligible_leads = query.limit(limit).all()
        else:
            eligible_leads = query.all()
        
        if not eligible_leads:
            return {
                "message": "No eligible leads found",
                "criteria": "Has website_url, no PageSpeed scores, no previous errors",
                "processed": 0
            }
        
        # Start PageSpeed tests in background
        service = PageSpeedService()
        lead_data = [(lead.id, lead.website_url) for lead in eligible_leads]
        background_tasks.add_task(service.test_multiple_leads_async, lead_data)
        
        # Log the action
        logger.info(f"Starting PageSpeed tests for {len(eligible_leads)} leads without scores")
        
        return {
            "message": f"PageSpeed tests started for {len(eligible_leads)} leads",
            "processed": len(eligible_leads),
            "leads": [
                {
                    "id": lead.id,
                    "business_name": lead.business_name,
                    "website_url": lead.website_url
                } for lead in eligible_leads[:10]  # Return first 10 for visibility
            ]
        }
    except Exception as e:
        logger.error(f"Error processing missing PageSpeed scores: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()


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


# Blacklist Management Endpoints
@app.get("/blacklist")
def get_blacklist():
    """Get all blacklisted businesses"""
    db = SessionLocal()
    try:
        blacklist_manager = BlacklistManager(db)
        blacklisted = blacklist_manager.get_all_blacklisted()
        return [
            {
                "business_name": b.business_name,
                "reason": b.reason,
                "notes": b.notes,
                "created_at": b.created_at.isoformat() if b.created_at else None
            }
            for b in blacklisted
        ]
    finally:
        db.close()


@app.post("/blacklist")
def add_to_blacklist(business_name: str, reason: str = "too_big", notes: str = None):
    """Add a business to the blacklist"""
    db = SessionLocal()
    try:
        blacklist_manager = BlacklistManager(db)
        success = blacklist_manager.add_to_blacklist(business_name, reason, notes)
        if success:
            return {"success": True, "message": f"Added '{business_name}' to blacklist"}
        else:
            return {"success": False, "message": f"'{business_name}' is already blacklisted"}
    finally:
        db.close()


@app.delete("/blacklist/{business_name}")
def remove_from_blacklist(business_name: str):
    """Remove a business from the blacklist"""
    db = SessionLocal()
    try:
        blacklist_manager = BlacklistManager(db)
        success = blacklist_manager.remove_from_blacklist(business_name)
        if success:
            return {"success": True, "message": f"Removed '{business_name}' from blacklist"}
        else:
            return {"success": False, "message": f"'{business_name}' not found in blacklist"}
    finally:
        db.close()


@app.get("/blacklist/count")
def get_blacklist_count():
    """Get count of blacklisted businesses"""
    db = SessionLocal()
    try:
        blacklist_manager = BlacklistManager(db)
        count = blacklist_manager.get_blacklist_count()
        return {"count": count}
    finally:
        db.close()


@app.post("/blacklist/initialize")
def initialize_blacklist_with_franchises():
    """Initialize blacklist with known franchises"""
    db = SessionLocal()
    try:
        count = initialize_blacklist(db)
        return {"success": True, "message": f"Initialized blacklist with {count} known franchises"}
    finally:
        db.close()


# Email Template endpoints
@app.get("/email-templates", response_model=List[EmailTemplateResponse])
def get_email_templates(active_only: bool = False):
    """Get all email templates"""
    db = SessionLocal()
    try:
        query = db.query(EmailTemplate)
        if active_only:
            query = query.filter(EmailTemplate.is_active == True)
        templates = query.order_by(EmailTemplate.created_at.desc()).all()
        return templates
    finally:
        db.close()


@app.get("/email-templates/{template_id}", response_model=EmailTemplateResponse)
def get_email_template(template_id: str):
    """Get a specific email template"""
    db = SessionLocal()
    try:
        template = db.query(EmailTemplate).filter(EmailTemplate.id == template_id).first()
        if not template:
            raise HTTPException(status_code=404, detail="Template not found")
        return template
    finally:
        db.close()


@app.post("/email-templates", response_model=EmailTemplateResponse)
def create_email_template(template: EmailTemplateCreate):
    """Create a new email template"""
    db = SessionLocal()
    try:
        # Check if template name already exists
        existing = db.query(EmailTemplate).filter(EmailTemplate.name == template.name).first()
        if existing:
            raise HTTPException(status_code=400, detail="Template with this name already exists")
        
        db_template = EmailTemplate(
            id=str(uuid.uuid4()),
            name=template.name,
            subject=template.subject,
            body=template.body,
            description=template.description,
            is_active=template.is_active
        )
        db.add(db_template)
        db.commit()
        db.refresh(db_template)
        return db_template
    finally:
        db.close()


@app.put("/email-templates/{template_id}", response_model=EmailTemplateResponse)
def update_email_template(template_id: str, template: EmailTemplateUpdate):
    """Update an email template"""
    db = SessionLocal()
    try:
        db_template = db.query(EmailTemplate).filter(EmailTemplate.id == template_id).first()
        if not db_template:
            raise HTTPException(status_code=404, detail="Template not found")
        
        # Check if new name conflicts with existing template
        if template.name and template.name != db_template.name:
            existing = db.query(EmailTemplate).filter(
                EmailTemplate.name == template.name,
                EmailTemplate.id != template_id
            ).first()
            if existing:
                raise HTTPException(status_code=400, detail="Template with this name already exists")
        
        update_data = template.dict(exclude_unset=True)
        for field, value in update_data.items():
            setattr(db_template, field, value)
        
        db_template.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(db_template)
        return db_template
    finally:
        db.close()


@app.delete("/email-templates/{template_id}")
def delete_email_template(template_id: str):
    """Delete an email template"""
    db = SessionLocal()
    try:
        template = db.query(EmailTemplate).filter(EmailTemplate.id == template_id).first()
        if not template:
            raise HTTPException(status_code=404, detail="Template not found")
        
        db.delete(template)
        db.commit()
        return {"message": "Template deleted successfully"}
    finally:
        db.close()


@app.post("/email-templates/initialize-defaults")
def initialize_default_templates():
    """Initialize default email templates if none exist"""
    db = SessionLocal()
    try:
        # Check if any templates exist
        existing_count = db.query(EmailTemplate).count()
        if existing_count > 0:
            return {"message": f"Templates already exist ({existing_count} found)", "created": 0}
        
        # Create default templates
        default_templates = [
            {
                "name": "Initial Outreach",
                "subject": "Website Performance Opportunity for {{businessName}}",
                "body": """Hi {{businessName}},

I noticed your business in {{location}} and wanted to reach out about your online presence.

Your current rating of {{rating}} with {{reviewCount}} reviews shows you're doing great work in the {{industry}} industry. However, I noticed some opportunities to improve your website's performance that could help you attract more customers.

Would you be interested in a brief conversation about how we can help improve your online visibility and website speed?

Best regards""",
                "description": "First contact email for new leads"
            },
            {
                "name": "Follow-up After Call",
                "subject": "Following Up - {{businessName}}",
                "body": """Hi {{businessName}},

Thank you for taking the time to speak with me today. As discussed, I wanted to follow up with some information about how we can help improve your online presence.

Based on our conversation, here are the key areas where we can help:
- Improve website loading speed
- Enhance mobile user experience  
- Boost local search visibility

I'll send over a detailed proposal shortly. Please let me know if you have any questions in the meantime.

Best regards""",
                "description": "Send after initial phone call"
            },
            {
                "name": "Website Improvement Proposal",
                "subject": "Website Improvement Proposal for {{businessName}}",
                "body": """Hi {{businessName}},

As promised, I'm sending over our website improvement proposal for your {{industry}} business in {{location}}.

[PAGESPEED_SUMMARY]

[PAGESPEED_DETAILS]

[PERFORMANCE_ISSUES]

Our proposed improvements will:
[IMPROVEMENT_AREAS]

Additional benefits:
- Increase conversion rates by 20-40%
- Improve search engine rankings
- Enhance user experience across all devices
- Reduce bounce rates

Investment: Starting at $X,XXX
Timeline: 2-3 weeks

Would you like to schedule a call to discuss this proposal in detail?

Best regards""",
                "description": "Detailed proposal with PageSpeed data"
            },
            {
                "name": "PageSpeed Results",
                "subject": "Website Performance Analysis for {{businessName}}",
                "body": """Hi {{businessName}},

I've completed a performance analysis of your website and wanted to share the results with you.

[PAGESPEED_SUMMARY]

[PERFORMANCE_ISSUES]

The good news is that these issues are fixable! With some targeted optimizations, we can:
[IMPROVEMENT_AREAS]

Current scores:
- Mobile Performance: {{mobileScore}}/100
- Desktop Performance: {{desktopScore}}/100
- SEO Score: {{seoScore}}/100
- Accessibility: {{accessibilityScore}}/100

Would you like to discuss how we can improve these scores and boost your online presence?

Best regards""",
                "description": "Share PageSpeed test results"
            },
            {
                "name": "Thank You - Not Interested",
                "subject": "Thank You {{businessName}}",
                "body": """Hi {{businessName}},

Thank you for taking the time to consider our services. I understand that now might not be the right time for website improvements.

I'll keep your information on file, and please don't hesitate to reach out if your needs change in the future. We're always here to help businesses in {{location}} improve their online presence.

Wishing you continued success with your {{industry}} business.

Best regards""",
                "description": "Polite follow-up for leads that decline"
            }
        ]
        
        created_count = 0
        for template_data in default_templates:
            db_template = EmailTemplate(
                id=str(uuid.uuid4()),
                name=template_data["name"],
                subject=template_data["subject"],
                body=template_data["body"],
                description=template_data["description"],
                is_active=True
            )
            db.add(db_template)
            created_count += 1
        
        db.commit()
        return {"message": f"Default templates created successfully", "created": created_count}
    finally:
        db.close()


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)