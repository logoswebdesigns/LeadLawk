#!/usr/bin/env python3
"""
Main scraper execution logic
"""

import time
import threading
from datetime import datetime
from schemas import BrowserAutomationRequest
from job_management import update_job_status, add_job_log, job_threads


def run_scraper(job_id: str, params: BrowserAutomationRequest):
    """Run the browser automation scraper for a job"""
    
    def scraper_task():
        results = []
        
        try:
            # Construct search query if not provided
            search_query = params.query
            if not search_query:
                search_query = f"{params.industry} {params.location}"
            
            update_job_status(job_id, "running", message="Starting browser automation...", 
                             industry=params.industry, location=params.location, 
                             query=search_query, limit=params.limit)
            add_job_log(job_id, f"🚀 Starting browser automation job")
            add_job_log(job_id, f"📋 Industry: {params.industry}, Location: {params.location}")
            add_job_log(job_id, f"🔍 Search query: {search_query}")
            add_job_log(job_id, f"📋 Parameters: limit={params.limit}, min_rating={params.min_rating}, min_reviews={params.min_reviews}")
            
            # Import and initialize browser automation
            from browser_automation import BrowserAutomation
            automation = BrowserAutomation(job_id=job_id)
            
            # Setup browser
            if not automation.setup_browser():
                raise Exception("Failed to setup browser")
            
            add_job_log(job_id, "✅ Browser initialized successfully")
            
            # Check if job was cancelled before starting search
            from job_management import job_statuses
            if job_id in job_statuses and job_statuses[job_id].get("status") == "cancelled":
                add_job_log(job_id, "🛑 Job cancelled before search started")
                return
            
            # Perform the search
            update_job_status(job_id, "running", message="Searching for businesses...")
            
            results = automation.search_google_maps(
                query=search_query,
                limit=params.limit,
                min_rating=params.min_rating,
                min_reviews=params.min_reviews,
                requires_website=params.requires_website,
                recent_review_months=params.recent_review_months,
                enable_pagespeed=params.enable_pagespeed,
                max_pagespeed_score=params.max_pagespeed_score
            )
            
            # Clean up
            automation.close()
            
            # Update final status
            if job_id in job_statuses and job_statuses[job_id].get("status") == "cancelled":
                add_job_log(job_id, f"🛑 Job cancelled. Found {len(results)} results before cancellation")
                update_job_status(job_id, "cancelled", len(results), params.limit, f"Job cancelled. Found {len(results)} businesses")
            else:
                add_job_log(job_id, f"✅ Search completed! Found {len(results)} qualifying businesses")
                update_job_status(job_id, "completed", len(results), params.limit, f"Search completed successfully")
            
        except Exception as e:
            error_message = f"❌ Error during automation: {str(e)}"
            add_job_log(job_id, error_message)
            update_job_status(job_id, "failed", len(results), params.limit, f"Job failed: {str(e)}")
            print(f"Job {job_id} failed: {e}")
    
    # Run scraper in a separate thread
    thread = threading.Thread(target=scraper_task, daemon=True)
    job_threads[job_id] = thread
    thread.start()


def _scrape_prerequisites() -> tuple[bool, list[str]]:
    """Check if all prerequisites for scraping are met"""
    errors = []
    
    try:
        # Test database connection
        from database import SessionLocal
        from sqlalchemy import text
        db = SessionLocal()
        db.execute(text("SELECT 1"))
        db.close()
    except Exception as e:
        errors.append(f"Database connection failed: {str(e)}")
    
    try:
        # Test browser automation import
        from browser_automation import BrowserAutomation
    except Exception as e:
        errors.append(f"Browser automation import failed: {str(e)}")
    
    # Check for screenshot directory
    import os
    if not os.path.exists("screenshots"):
        try:
            os.makedirs("screenshots")
        except Exception as e:
            errors.append(f"Could not create screenshots directory: {str(e)}")
    
    return len(errors) == 0, errors