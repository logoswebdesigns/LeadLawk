#!/usr/bin/env python3
"""
Parallel job execution system for running multiple searches simultaneously
"""

import os
import uuid
import time
import threading
import queue
import requests
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import List, Dict, Any, Optional
from datetime import datetime
from selenium import webdriver
from selenium.webdriver.chrome.options import Options

from schemas import BrowserAutomationRequest
from job_management import update_job_status, add_job_log, job_statuses
from browser_automation import BrowserAutomation


class ParallelJobExecutor:
    """Execute multiple search jobs in parallel using Selenium Grid"""
    
    def __init__(self, max_workers: int = 8):
        self.max_workers = max_workers
        self.executor = ThreadPoolExecutor(max_workers=max_workers)
        self.active_jobs = {}
        self.job_queue = queue.Queue()
        self.selenium_hub_url = os.getenv('SELENIUM_HUB_URL', 'http://selenium-hub:4444/wd/hub')
        print(f"🔧 ParallelJobExecutor initialized with max_workers={max_workers}")
        
    def create_multi_location_jobs(self, 
                                 industries: List[str], 
                                 locations: List[str],
                                 base_params: Dict[str, Any]) -> Dict[str, List[str]]:
        """Create individual jobs for each industry-location combination"""
        job_matrix = {}
        parent_job_id = str(uuid.uuid4())
        child_job_ids = []
        
        # Create parent job for tracking
        job_statuses[parent_job_id] = {
            "id": parent_job_id,
            "type": "parent",
            "status": "pending",
            "total_combinations": len(industries) * len(locations),
            "completed_combinations": 0,
            "child_jobs": [],
            "industries": industries,
            "locations": locations,
            "created_at": datetime.utcnow().isoformat()
        }
        
        # Create child jobs for each combination
        for industry in industries:
            for location in locations:
                child_job_id = str(uuid.uuid4())
                child_job_ids.append(child_job_id)
                
                # Create job parameters
                # requires_website: None = both, True = only with websites, False = only without websites
                requires_website_value = base_params.get('requires_website', None)
                enable_pagespeed_value = base_params.get('enable_pagespeed', False)
                max_pagespeed_score_value = base_params.get('max_pagespeed_score', None)
                
                job_params = BrowserAutomationRequest(
                    industry=industry,
                    location=location,
                    query=f"{industry} in {location}",
                    limit=base_params.get('limit', 50),
                    min_rating=base_params.get('min_rating', 0),
                    min_reviews=base_params.get('min_reviews', 0),
                    requires_website=requires_website_value,
                    recent_review_months=base_params.get('recent_review_months', 24),
                    enable_pagespeed=enable_pagespeed_value,
                    max_pagespeed_score=max_pagespeed_score_value
                )
                
                # Log the parameters for this job
                website_filter = "both (no filter)" if requires_website_value is None else f"only {'WITH' if requires_website_value else 'WITHOUT'} websites"
                print(f"📋 Creating job for {industry} in {location}:")
                print(f"    Website filter: {website_filter}")
                print(f"    PageSpeed enabled: {enable_pagespeed_value}")
                if enable_pagespeed_value:
                    print(f"    Max PageSpeed score: {max_pagespeed_score_value}")
                
                # Store job info
                job_statuses[child_job_id] = {
                    "id": child_job_id,
                    "type": "child",
                    "parent_id": parent_job_id,
                    "status": "queued",
                    "industry": industry,
                    "location": location,
                    "params": job_params.dict(),
                    "created_at": datetime.utcnow().isoformat()
                }
                
                # Add to queue
                self.job_queue.put((child_job_id, job_params))
        
        # Update parent with child IDs
        job_statuses[parent_job_id]["child_jobs"] = child_job_ids
        job_matrix["parent_id"] = parent_job_id
        job_matrix["child_ids"] = child_job_ids
        
        return job_matrix
    
    def execute_parallel_jobs(self, job_matrix: Dict[str, Any]) -> Dict[str, Any]:
        """Execute all jobs in parallel using available Selenium nodes"""
        parent_id = job_matrix["parent_id"]
        child_ids = job_matrix["child_ids"]
        
        # Update parent status
        update_job_status(parent_id, "running", 
                         message=f"Starting {len(child_ids)} parallel searches")
        add_job_log(parent_id, f"🚀 Launching {len(child_ids)} parallel searches")
        print(f"🌐 Starting {len(child_ids)} parallel browser sessions (max concurrent: {self.max_workers})")
        
        # Submit all jobs to executor
        futures = {}
        while not self.job_queue.empty():
            job_id, params = self.job_queue.get()
            future = self.executor.submit(self._execute_single_job, job_id, params)
            futures[future] = job_id
            add_job_log(parent_id, f"📋 Submitted job {job_id}: {params.industry} in {params.location}")
        
        # Monitor completion
        completed = 0
        failed = 0
        results = {}
        
        for future in as_completed(futures):
            job_id = futures[future]
            try:
                result = future.result()
                results[job_id] = result
                completed += 1
                
                if result.get("status") == "completed":
                    add_job_log(parent_id, f"✅ Completed: {result.get('industry')} in {result.get('location')} - Found {result.get('leads_found', 0)} leads")
                else:
                    failed += 1
                    add_job_log(parent_id, f"❌ Failed: {result.get('industry')} in {result.get('location')}")
                
                # Update parent progress
                job_statuses[parent_id]["completed_combinations"] = completed
                update_job_status(parent_id, "running", 
                                completed, len(child_ids),
                                f"Progress: {completed}/{len(child_ids)} searches complete")
                
            except Exception as e:
                failed += 1
                add_job_log(parent_id, f"❌ Job {job_id} failed with error: {str(e)}")
        
        # Final status
        if failed == 0:
            update_job_status(parent_id, "completed", 
                            completed, len(child_ids),
                            f"All {completed} searches completed successfully")
            add_job_log(parent_id, f"🎉 All searches completed successfully!")
        else:
            update_job_status(parent_id, "partial", 
                            completed, len(child_ids),
                            f"Completed {completed} searches, {failed} failed")
            add_job_log(parent_id, f"⚠️ Completed with {failed} failures")
        
        return results
    
    def _execute_single_job(self, job_id: str, params: BrowserAutomationRequest) -> Dict[str, Any]:
        """Execute a single search job using shared Selenium Grid"""
        
        try:
            update_job_status(job_id, "initializing", 
                            message=f"Preparing to search {params.industry} in {params.location}")
            add_job_log(job_id, f"🔍 Starting search: {params.query}")
            
            # Use shared Selenium Grid instead of spawning containers
            add_job_log(job_id, f"🌐 Connecting to shared Selenium Grid for {params.industry}")
            
            update_job_status(job_id, "running", 
                            message=f"Searching {params.industry} in {params.location}")
            
            # Create browser automation instance - always use headless for parallel jobs
            automation = BrowserAutomation(job_id=job_id, headless=True)
            
            # Connect to the shared Selenium Grid (no container spawning)
            if not automation.setup_browser():
                raise Exception("Failed to connect to Selenium Grid")
            
            add_job_log(job_id, "✅ Connected to Selenium Grid browser session")
            
            # Perform the search
            results = automation.search_google_maps(
                query=params.query,
                limit=params.limit,
                min_rating=params.min_rating,
                min_reviews=params.min_reviews,
                requires_website=params.requires_website,
                recent_review_months=params.recent_review_months,
                enable_pagespeed=params.enable_pagespeed,
                max_pagespeed_score=params.max_pagespeed_score
            )
            
            # Clean up browser session
            automation.close()
            add_job_log(job_id, "🧹 Cleaned up browser session")
            
            # Update job status
            update_job_status(job_id, "completed", 
                            len(results), params.limit,
                            f"Found {len(results)} qualifying businesses")
            
            return {
                "job_id": job_id,
                "status": "completed",
                "industry": params.industry,
                "location": params.location,
                "leads_found": len(results),
                "results": results
            }
            
        except Exception as e:
            update_job_status(job_id, "failed", 
                            message=f"Error: {str(e)}")
            add_job_log(job_id, f"❌ Job failed: {str(e)}")
            
            return {
                "job_id": job_id,
                "status": "failed",
                "industry": params.industry,
                "location": params.location,
                "error": str(e)
            }
    
    
    def get_grid_status(self) -> Dict[str, Any]:
        """Get status of Selenium Grid"""
        import requests
        try:
            # Check if we're using Docker Selenium hub
            selenium_url = os.getenv('SELENIUM_HUB_URL', 'http://selenium-chrome:4444/wd/hub')
            # Extract base URL for status endpoint
            base_url = selenium_url.replace('/wd/hub', '')
            response = requests.get(f"{base_url}/wd/hub/status", timeout=5)
            if response.status_code == 200:
                data = response.json()
                value = data.get('value', {})
                nodes = value.get('nodes', [])
                return {
                    "ready": value.get('ready', False),
                    "nodes": len(nodes),
                    "message": value.get('message', 'Unknown status')
                }
        except Exception as e:
            print(f"Error checking Selenium Grid status: {e}")
        
        # Fallback: return not ready
        return {
            "ready": False,
            "nodes": 0,
            "error": "Could not connect to Selenium Grid"
        }
    
    def cleanup_infrastructure(self) -> bool:
        """Clean up any orphaned resources"""
        try:
            # No container cleanup needed - we use shared Selenium Grid
            return True
        except Exception as e:
            print(f"Error during cleanup: {e}")
            return False


# Global executor instance
# max_workers determines how many jobs can be in flight at once
# Set to 50 to match Selenium Grid capacity
# Initialize with reasonable defaults for parallel execution
# Increased to 10 concurrent sessions to match Selenium capacity
parallel_executor = ParallelJobExecutor(max_workers=10)