from fastapi import FastAPI, HTTPException, BackgroundTasks, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, Dict, Any, List
import uuid
import threading
from datetime import datetime
import subprocess
import sys
import json
import os
from pathlib import Path
import shutil
import asyncio
from collections import defaultdict
import logging
from logging.handlers import RotatingFileHandler

from database import SessionLocal, init_db
from models import Lead, LeadStatus
from schemas import LeadResponse, LeadUpdate, ScrapeRequest, JobResponse

app = FastAPI(title="LeadLoq API")

# Custom robust rotating file handler that handles rotation errors gracefully
class RobustRotatingFileHandler(RotatingFileHandler):
    def doRollover(self):
        """Override rollover to handle file busy errors gracefully"""
        try:
            super().doRollover()
        except (OSError, IOError) as e:
            # If rotation fails, just continue logging to the current file
            # This prevents the entire logging system from failing
            pass
    
    def emit(self, record):
        """Override emit to handle any logging errors gracefully"""
        try:
            super().emit(record)
        except (OSError, IOError, ValueError):
            # Silently ignore logging errors to prevent stack trace spam
            pass

# Configure logging to a rotating file
LOG_PATH = Path(__file__).resolve().parent / "server.log"
LOG_PATH.parent.mkdir(parents=True, exist_ok=True)

# Create a simple file handler instead of rotating for Docker environments
try:
    logger = logging.getLogger("leadlawk")
    logger.setLevel(logging.INFO)
    
    # Use our robust handler
    _handler = RobustRotatingFileHandler(LOG_PATH, maxBytes=1_000_000, backupCount=3)
    _formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    _handler.setFormatter(_formatter)
    
    if not any(isinstance(h, (RotatingFileHandler, RobustRotatingFileHandler)) for h in logger.handlers):
        logger.addHandler(_handler)

    # Suppress uvicorn access logs to reduce noise
    uvicorn_access = logging.getLogger("uvicorn.access")
    uvicorn_access.handlers.clear()
    uvicorn_access.propagate = False
    
    # Only forward error logs from uvicorn
    for _name in ("uvicorn", "uvicorn.error"):
        _uv = logging.getLogger(_name)
        if not any(isinstance(h, (RotatingFileHandler, RobustRotatingFileHandler)) for h in _uv.handlers):
            _robust_handler = RobustRotatingFileHandler(LOG_PATH, maxBytes=1_000_000, backupCount=3)
            _robust_handler.setFormatter(_formatter)
            _uv.addHandler(_robust_handler)

except Exception:
    # If logging setup fails completely, create a minimal console handler
    logger = logging.getLogger("leadlawk")
    logger.setLevel(logging.INFO)
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(logging.Formatter('%(asctime)s - %(levelname)s - %(message)s'))
    logger.addHandler(console_handler)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

jobs: Dict[str, Dict[str, Any]] = {}
job_lock = threading.Lock()
job_logs: Dict[str, List[str]] = defaultdict(list)
active_connections: Dict[str, List[WebSocket]] = defaultdict(list)
logs_connections: List[WebSocket] = []
event_loop: asyncio.AbstractEventLoop | None = None
job_threads: Dict[str, threading.Thread] = {}  # Track running threads for cancellation
job_automations: Dict[str, Any] = {}  # Track automation objects for cancellation


def update_job_status(job_id: str, status: str, processed: int = 0, total: int = 0, message: Optional[str] = None):
    with job_lock:
        if job_id in jobs:
            jobs[job_id].update({
                "status": status,
                "processed": processed,
                "total": total,
                "message": message,
                "updated_at": datetime.utcnow().isoformat()
            })
            
def cleanup_old_jobs(max_jobs=3):
    """Keep only the most recent jobs and their associated files"""
    try:
        with job_lock:
            if len(jobs) <= max_jobs:
                return
            
            # Sort jobs by creation time (oldest first)
            job_items = list(jobs.items())
            job_items.sort(key=lambda x: x[1].get("created_at", ""))
            
            # Identify jobs to remove (all but the most recent max_jobs)
            jobs_to_remove = job_items[:-max_jobs]
            
            for job_id, job_data in jobs_to_remove:
                logger.info(f"🧹 Cleaning up old job: {job_id}")
                
                # Remove job from memory
                del jobs[job_id]
                if job_id in job_logs:
                    del job_logs[job_id]
                if job_id in active_connections:
                    del active_connections[job_id]
                
                # Clean up screenshots for this job
                try:
                    import os
                    screenshots_dir = Path("/app/screenshots")
                    if screenshots_dir.exists():
                        deleted_count = 0
                        for filename in os.listdir(screenshots_dir):
                            if filename.startswith(f"job_{job_id}_") and filename.endswith(".png"):
                                screenshot_path = screenshots_dir / filename
                                os.remove(screenshot_path)
                                deleted_count += 1
                        if deleted_count > 0:
                            logger.info(f"🗑️ Deleted {deleted_count} screenshots for job {job_id}")
                except Exception as e:
                    logger.error(f"⚠️ Error cleaning screenshots for job {job_id}: {e}")
    except Exception as e:
        logger.error(f"Error in cleanup_old_jobs: {e}")

def add_job_log(job_id: str, log_message: str):
    timestamp = datetime.utcnow().isoformat()
    formatted_log = f"[{timestamp}] {log_message}"
    job_logs[job_id].append(formatted_log)
    # Persist to server log as well - suppress logging errors
    try:
      logger.info(f"JOB {job_id}: {log_message}")
    except Exception:
      # Silently ignore logging errors to prevent stack trace spam
      pass
    # Send to connected WebSocket clients
    try:
        # If we're on the event loop thread
        loop = asyncio.get_running_loop()
        asyncio.create_task(broadcast_log(job_id, formatted_log))
    except RuntimeError:
        # Called from a background thread: submit to main loop
        if event_loop is not None:
            try:
                asyncio.run_coroutine_threadsafe(broadcast_log(job_id, formatted_log), event_loop)
            except Exception as e:
                # Log the error but don't crash the scraper
                logger.error(f"Failed to broadcast log: {e}")
    
async def broadcast_log(job_id: str, log_message: str):
    for websocket in active_connections.get(job_id, []):
        try:
            await websocket.send_json({
                "type": "log",
                "message": log_message
            })
        except Exception:
            pass


def run_scraper(job_id: str, params: ScrapeRequest):
    """Run the lead fetcher using the compliant maps proxy service"""
    try:
        update_job_status(job_id, "running", 0, params.limit)
        add_job_log(job_id, f"Starting lead fetch for {params.industry} in {params.location}")
        add_job_log(job_id, f"Search parameters: {params.limit} leads, min rating {params.min_rating}, min reviews {params.min_reviews}")
        add_job_log(job_id, f"Using compliant maps proxy service at http://maps-proxy:8001")
        
        # Check if mock mode is requested
        if params.mock or os.environ.get("USE_MOCK_DATA", "").lower() in ("true", "1", "yes"):
            add_job_log(job_id, "Mock mode enabled - simulating Google Places API data")
            # Generate realistic mock data that simulates Google Places API responses
            from database import SessionLocal
            from models import Lead, LeadStatus
            import random
            
            # Realistic business data based on industry
            mock_templates = {
                "restaurants": [
                    {"name": "Franklin Barbecue", "phone": "(512) 653-1187", "website": "https://franklinbbq.com", "rating": 4.7, "reviews": 8453},
                    {"name": "Uchi Austin", "phone": "(512) 916-4808", "website": "https://uchiaustin.com", "rating": 4.6, "reviews": 3421},
                    {"name": "Matt's El Rancho", "phone": "(512) 462-9333", "website": "https://mattselrancho.com", "rating": 4.4, "reviews": 2156},
                    {"name": "La Condesa", "phone": "(512) 499-0300", "website": "https://lacondesa.com", "rating": 4.3, "reviews": 1876},
                    {"name": "Torchy's Tacos", "phone": "(512) 366-0537", "website": "https://torchystacos.com", "rating": 4.2, "reviews": 4532}
                ],
                "dentist": [
                    {"name": "Austin Dental Care", "phone": "(512) 454-6936", "website": "https://austindentalcare.com", "rating": 4.8, "reviews": 542},
                    {"name": "Westlake Dental Associates", "phone": "(512) 328-0505", "website": "https://westlakedental.com", "rating": 4.9, "reviews": 387},
                    {"name": "South Austin Dental", "phone": "(512) 444-0021", "website": None, "rating": 4.5, "reviews": 198},
                    {"name": "Castle Dental", "phone": "(512) 442-4204", "website": "https://castledental.com", "rating": 4.1, "reviews": 876},
                    {"name": "Bright Smile Family Dentistry", "phone": "(512) 458-6222", "website": None, "rating": 4.6, "reviews": 234}
                ],
                "coffee shops": [
                    {"name": "Houndstooth Coffee", "phone": "(512) 394-6051", "website": "https://houndstoothcoffee.com", "rating": 4.5, "reviews": 876},
                    {"name": "Mozart's Coffee Roasters", "phone": "(512) 477-2900", "website": "https://mozartscoffee.com", "rating": 4.4, "reviews": 3234},
                    {"name": "Epoch Coffee", "phone": "(512) 454-3762", "website": None, "rating": 4.3, "reviews": 1543},
                    {"name": "Radio Coffee & Beer", "phone": "(512) 394-7844", "website": "https://radiocoffeeandbeer.com", "rating": 4.6, "reviews": 2109},
                    {"name": "Merit Coffee", "phone": "(512) 987-2132", "website": "https://meritcoffee.com", "rating": 4.7, "reviews": 654}
                ]
            }
            
            # Default template for any industry
            default_template = [
                {"name": f"Premier {params.industry.title()}", "phone": "(512) 555-0100", "website": f"https://premier{params.industry.replace(' ', '')}.com", "rating": 4.6, "reviews": 432},
                {"name": f"{params.location.split(',')[0]} {params.industry.title()}", "phone": "(512) 555-0200", "website": None, "rating": 4.3, "reviews": 287},
                {"name": f"Elite {params.industry.title()} Services", "phone": "(512) 555-0300", "website": f"https://elite{params.industry.replace(' ', '')}.com", "rating": 4.8, "reviews": 765},
                {"name": f"Quality {params.industry.title()} Co", "phone": "(512) 555-0400", "website": None, "rating": 4.1, "reviews": 123},
                {"name": f"Top Rated {params.industry.title()}", "phone": "(512) 555-0500", "website": f"https://toprated{params.industry.replace(' ', '')}.com", "rating": 4.9, "reviews": 1432}
            ]
            
            # Select appropriate template
            templates = mock_templates.get(params.industry.lower(), default_template)
            
            db = SessionLocal()
            try:
                count = min(len(templates), params.limit)
                saved_count = 0
                duplicate_count = 0
                for i in range(count):
                    template = templates[i]
                    
                    # Check for duplicates
                    existing_lead = db.query(Lead).filter(
                        Lead.business_name == template["name"],
                        Lead.phone == template["phone"]
                    ).first()
                    
                    if existing_lead:
                        duplicate_count += 1
                        add_job_log(job_id, f"Duplicate: {template['name']} (mock) - skipped")
                        continue
                    
                    # Add some variation to ratings and reviews
                    rating = template["rating"] + random.uniform(-0.2, 0.2)
                    rating = max(3.5, min(5.0, round(rating, 1)))
                    review_count = int(template["reviews"] * random.uniform(0.8, 1.2))
                    
                    lead = Lead(
                        business_name=template["name"],
                        phone=template["phone"],
                        website_url=template["website"],
                        profile_url=f"https://maps.google.com/maps/place/{template['name'].replace(' ', '+')}",
                        rating=rating,
                        review_count=review_count,
                        location=params.location,
                        industry=params.industry,
                        source="google_maps_mock",
                        status=LeadStatus.NEW,
                        has_website=template["website"] is not None,
                        is_candidate=template["website"] is None,  # Candidate if no website
                        meets_rating_threshold=rating >= params.min_rating,
                        has_recent_reviews=review_count >= params.min_reviews,
                        created_at=datetime.utcnow(),
                        updated_at=datetime.utcnow()
                    )
                    db.add(lead)
                    saved_count += 1
                    update_job_status(job_id, "running", saved_count, count)
                    add_job_log(job_id, f"Found: {lead.business_name} - ⭐ {rating} ({review_count} reviews)")
                
                db.commit()
                update_job_status(job_id, "done", saved_count, params.limit)
                if duplicate_count > 0:
                    add_job_log(job_id, f"Mock simulation complete: {saved_count} new leads, {duplicate_count} duplicates skipped")
                else:
                    add_job_log(job_id, f"Mock Google Places API simulation complete: {saved_count} leads")
                
                # Cleanup old jobs after successful completion
                cleanup_old_jobs(max_jobs=3)
            finally:
                db.close()
        else:
            # Use the compliant lead fetcher with maps proxy
            import asyncio
            from lead_fetcher import LeadFetcher
            
            # Run the async lead fetcher
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            
            try:
                fetcher = LeadFetcher(maps_proxy_url="http://maps-proxy:8001")
                leads = loop.run_until_complete(
                    fetcher.fetch_leads(
                        industry=params.industry,
                        location=params.location,
                        limit=params.limit,
                        min_rating=params.min_rating,
                        min_reviews=params.min_reviews
                    )
                )
                
                # Update progress as leads are saved
                for i, lead in enumerate(leads):
                    update_job_status(job_id, "running", i+1, params.limit)
                    add_job_log(job_id, f"Found lead: {lead.get('business_name', 'Unknown')}")
                
                add_job_log(job_id, f"Successfully fetched {len(leads)} leads from APIs")
                update_job_status(job_id, "done", len(leads), params.limit)
            finally:
                loop.close()
            
    except Exception as e:
        add_job_log(job_id, f"Error: {str(e)}")
        update_job_status(job_id, "error", 0, params.limit, str(e))


@app.on_event("startup")
async def startup_event():
    global event_loop
    event_loop = asyncio.get_running_loop()
    init_db()


@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "service": "LeadLawk API",
        "timestamp": datetime.utcnow().isoformat()
    }




@app.get("/diagnostics")
async def diagnostics():
    """Run environment diagnostics for scraping and API health."""
    ok, messages = _scrape_prerequisites()
    # DB check
    db_ok = True
    leads_count = None
    try:
        db = SessionLocal()
        leads_count = db.query(Lead).count()
        db.close()
    except Exception as e:
        db_ok = False
        messages.append(f"DB error: {e}")
    # Log path check
    log_ok = True
    try:
        LOG_PATH.touch(exist_ok=True)
    except Exception as e:
        log_ok = False
        messages.append(f"Log path error: {e}")

    return {
        "scraper_ready": ok,
        "db_ok": db_ok,
        "log_ok": log_ok,
        "python": sys.executable,
        "cwd": str(Path.cwd()),
        "use_mock_data": os.environ.get("USE_MOCK_DATA"),
        "leads_count": leads_count,
        "messages": messages,
    }


@app.post("/jobs/scrape", response_model=Dict[str, str])
async def start_scrape(request: ScrapeRequest, background_tasks: BackgroundTasks):
    job_id = str(uuid.uuid4())
    
    with job_lock:
        jobs[job_id] = {
            "job_id": job_id,
            "status": "running",
            "processed": 0,
            "total": request.limit,
            "message": None,
            "created_at": datetime.utcnow().isoformat(),
            "updated_at": datetime.utcnow().isoformat()
        }
    
    # Preflight checks to provide actionable errors before launching
    ok, messages = _scrape_prerequisites()
    for m in messages:
        add_job_log(job_id, m)
    if not ok:
        update_job_status(job_id, "error", 0, request.limit, "; ".join(messages))
    else:
        thread = threading.Thread(target=run_scraper, args=(job_id, request))
        thread.start()
    
    return {"job_id": job_id}


@app.post("/jobs/browser", response_model=Dict[str, Any])
async def start_browser_automation(request: ScrapeRequest, background_tasks: BackgroundTasks):
    """Start a browser-based scrape using Selenium automation"""
    # DEBUG: Print what we received from the API request
    print(f"🔧 API DEBUG: request.recent_review_months = {getattr(request, 'recent_review_months', 'MISSING')}")
    print(f"🔧 API DEBUG: request fields = {[attr for attr in dir(request) if not attr.startswith('_')]}")
    
    job_id = str(uuid.uuid4())
    
    with job_lock:
        jobs[job_id] = {
            "job_id": job_id,
            "status": "running",
            "processed": 0,
            "total": request.limit,
            "message": "Initializing browser automation...",
            "created_at": datetime.utcnow().isoformat(),
            "updated_at": datetime.utcnow().isoformat(),
            "scraper_type": "browser"
        }
    
    def run_browser_scraper(job_id: str, params: ScrapeRequest):
        """Run the browser automation to collect leads"""
        try:
            from browser_automation import BrowserAutomation
            add_job_log(job_id, "🔧 DEBUG: Imported BrowserAutomation successfully")
            
            add_job_log(job_id, "Starting browser automation with Selenium")
            add_job_log(job_id, f"Target: {params.industry} in {params.location}")
            add_job_log(job_id, f"Parameters: {params.limit} leads, min rating {params.min_rating}")
            # Debug params object
            print(f"🔧 SERVER DEBUG: params attributes = {dir(params)}")
            print(f"🔧 SERVER DEBUG: params.recent_review_months = {getattr(params, 'recent_review_months', 'MISSING')}")
            add_job_log(job_id, f"🔧 DEBUG: recent_review_months = {getattr(params, 'recent_review_months', 'NOT_FOUND')}")
            
            # Log website filter requirement
            requires_website = getattr(params, 'requires_website', None)
            if requires_website is None:
                add_job_log(job_id, "Website filter: ANY (all businesses)")
            elif requires_website == False:
                add_job_log(job_id, "Website filter: NO WEBSITE ONLY (ideal prospects)")
            elif requires_website == True:
                add_job_log(job_id, "Website filter: MUST HAVE WEBSITE")
            
            # Check if we should use mock data
            if params.use_mock_data:
                add_job_log(job_id, "Using mock data for testing")
                # Generate mock leads
                import random
                db = SessionLocal()
                try:
                    for i in range(min(params.limit, 10)):
                        lead = Lead(
                            business_name=f"Test {params.industry} #{i+1}",
                            phone=f"(512) 555-{1000+i:04d}",
                            website_url=f"https://test{i+1}.com" if i % 2 == 0 else None,
                            profile_url=f"https://maps.google.com/test{i+1}",
                            rating=round(random.uniform(3.5, 5.0), 1),
                            review_count=random.randint(10, 500),
                            location=params.location,
                            industry=params.industry,
                            source="browser_automation_mock",
                            status=LeadStatus.NEW,
                            has_website=i % 2 == 0,
                            is_candidate=i % 2 != 0,
                            meets_rating_threshold=True,
                            has_recent_reviews=True,
                            created_at=datetime.utcnow(),
                            updated_at=datetime.utcnow()
                        )
                        db.add(lead)
                        update_job_status(job_id, "running", i+1, params.limit)
                        add_job_log(job_id, f"Mock lead: {lead.business_name}")
                    db.commit()
                    update_job_status(job_id, "done", params.limit, params.limit)
                    add_job_log(job_id, f"Mock data generation complete: {params.limit} leads")
                finally:
                    db.close()
                return
            
            # Initialize browser automation
            use_profile = getattr(params, 'use_profile', False)
            headless = getattr(params, 'headless', False)
            use_browser_automation = getattr(params, 'use_browser_automation', True)
            
            if not use_browser_automation:
                # Fall back to API-based approach if browser automation is disabled
                add_job_log(job_id, "Browser automation disabled, using API approach")
                update_job_status(job_id, "error", 0, params.limit, "Browser automation is disabled")
                return
            
            add_job_log(job_id, f"Browser mode: {'headless' if headless else 'visible'}")
            if use_profile:
                add_job_log(job_id, "Using your existing Chrome profile with saved logins")
            
            automation = BrowserAutomation(
                use_profile=use_profile,
                headless=headless,
                job_id=job_id
            )
            
            # Track automation object for cancellation
            job_automations[job_id] = automation
            
            # Navigate to Google Maps
            search_query = f"{params.industry} near {params.location}"
            add_job_log(job_id, f"Searching Google Maps for: {search_query}")
            
            results = automation.search_google_maps(
                query=search_query,
                limit=params.limit,
                min_rating=params.min_rating,
                min_reviews=params.min_reviews,
                requires_website=getattr(params, 'requires_website', None),
                recent_review_months=getattr(params, 'recent_review_months', None),
                min_photos=getattr(params, 'min_photos', None),
                min_description_length=getattr(params, 'min_description_length', None)
            )
            
            # Save results to database with duplicate prevention
            db = SessionLocal()
            try:
                saved_count = 0
                duplicate_count = 0
                for idx, result in enumerate(results):
                    business_name = result.get('name', 'Unknown')
                    phone = result.get('phone') or 'No phone'
                    
                    # Check for existing lead with same business name and phone
                    existing_lead = db.query(Lead).filter(
                        Lead.business_name == business_name,
                        Lead.phone == phone
                    ).first()
                    
                    if existing_lead:
                        duplicate_count += 1
                        add_job_log(job_id, f"Duplicate: {business_name} (already exists with phone {phone}) - skipped")
                        continue
                    
                    # Also check for duplicate by business name and location (in case phone changed)
                    name_location_duplicate = db.query(Lead).filter(
                        Lead.business_name == business_name,
                        Lead.location == params.location,
                        Lead.industry == params.industry
                    ).first()
                    
                    if name_location_duplicate:
                        duplicate_count += 1
                        add_job_log(job_id, f"Duplicate: {business_name} (already exists in {params.location}) - skipped")
                        continue
                    
                    # Create new lead if no duplicates found
                    lead = Lead(
                        business_name=business_name,
                        phone=phone,
                        website_url=result.get('website'),
                        profile_url=result.get('url', ''),
                        rating=float(result.get('rating', 0.0)),
                        review_count=int(result.get('reviews', 0)),
                        last_review_date=result.get('last_review_date'),
                        location=params.location,
                        industry=params.industry,
                        source="browser_automation",
                        status=LeadStatus.NEW,
                        has_website=result.get('website') is not None,
                        is_candidate=result.get('website') is None,
                        meets_rating_threshold=float(result.get('rating', 0)) >= params.min_rating,
                        has_recent_reviews=result.get('has_recent_reviews', False),
                        created_at=datetime.utcnow(),
                        updated_at=datetime.utcnow()
                    )
                    db.add(lead)
                    saved_count += 1
                    update_job_status(job_id, "running", saved_count, len(results))
                    add_job_log(job_id, f"New: {lead.business_name} - ⭐ {lead.rating} ({lead.review_count} reviews)")
                
                db.commit()
                update_job_status(job_id, "done", saved_count, len(results))
                
                # Log final results with duplicate info
                total_found = len(results)
                if duplicate_count > 0:
                    add_job_log(job_id, f"Browser automation complete: {saved_count} new leads saved, {duplicate_count} duplicates skipped (total found: {total_found})")
                else:
                    add_job_log(job_id, f"Browser automation complete: {saved_count} leads found")
                
                # Cleanup old jobs after successful completion
                cleanup_old_jobs(max_jobs=3)
            finally:
                db.close()
                automation.close()
                # Clean up automation tracking
                if job_id in job_automations:
                    del job_automations[job_id]
            
        except Exception as e:
            import traceback
            error_details = traceback.format_exc()
            update_job_status(job_id, "error", 0, params.limit, str(e))
            add_job_log(job_id, f"Error: {str(e)}")
            add_job_log(job_id, f"Traceback: {error_details}")
            
            # Clean up automation tracking on error
            if job_id in job_automations:
                try:
                    job_automations[job_id].close()
                except:
                    pass
                del job_automations[job_id]
    
    # Run in background thread
    thread = threading.Thread(target=run_browser_scraper, args=(job_id, request))
    thread.start()
    
    # Track the thread for potential cancellation
    with job_lock:
        job_threads[job_id] = thread
    
    return {"job_id": job_id, "type": "browser_automation"}


@app.get("/jobs")
async def list_jobs():
    """Return all current jobs (in-memory) sorted by updated_at desc."""
    with job_lock:
        all_jobs = list(jobs.values())
    def _ts(j):
        return j.get("updated_at") or j.get("created_at") or ""
    all_jobs.sort(key=_ts, reverse=True)
    return all_jobs


def _scrape_prerequisites() -> tuple[bool, list[str]]:
    msgs: list[str] = []
    ok = True
    # Check if maps proxy is available
    try:
        import httpx
        msgs.append("HTTP client: OK")
        msgs.append("Maps proxy service: http://maps-proxy:8001")
    except Exception as e:
        ok = False
        msgs.append(f"HTTP client import failed: {e}")
    return ok, msgs


@app.get("/jobs/{job_id}", response_model=JobResponse)
async def get_job_status(job_id: str):
    with job_lock:
        if job_id not in jobs:
            raise HTTPException(status_code=404, detail="Job not found")
        return JobResponse(**jobs[job_id])


@app.post("/jobs/{job_id}/cancel")
async def cancel_job(job_id: str):
    """Cancel a running job"""
    with job_lock:
        if job_id not in jobs:
            raise HTTPException(status_code=404, detail="Job not found")
        
        job = jobs[job_id]
        if job["status"] in ["done", "error", "cancelled"]:
            return {"success": False, "message": f"Job already {job['status']}"}
        
        # Update job status
        job["status"] = "cancelled"
        job["message"] = "Job cancelled by user"
        job["updated_at"] = datetime.utcnow().isoformat()
        
        # Try to stop the browser automation immediately
        if job_id in job_automations:
            try:
                automation = job_automations[job_id]
                automation.close()  # Close browser session immediately
                add_job_log(job_id, "Browser session closed")
                del job_automations[job_id]  # Clean up
            except Exception as e:
                add_job_log(job_id, f"Error closing browser session: {e}")
        
        # Try to stop the thread if it exists
        if job_id in job_threads:
            # Note: Thread interruption in Python is limited
            # The actual job should check for cancellation status periodically
            add_job_log(job_id, "Cancellation requested by user")
        
        return {"success": True, "message": "Job cancellation requested"}


@app.get("/jobs/{job_id}/logs")
async def get_job_logs(job_id: str, tail: int = 500):
    """Return the last N lines for a given job's in-memory logs.

    Note: For live updates, prefer the existing WebSocket at /ws/jobs/{job_id}.
    """
    with job_lock:
        lines = list(job_logs.get(job_id, []))
    tail = max(1, min(tail, 5000))
    return {"job_id": job_id, "lines": lines[-tail:]}

@app.get("/leads", response_model=list[LeadResponse])
async def get_leads(
    status: Optional[str] = None,
    search: Optional[str] = None,
    candidates_only: Optional[bool] = None
):
    db = SessionLocal()
    try:
        query = db.query(Lead)
        
        if status:
            query = query.filter(Lead.status == status)
        
        if search:
            search_pattern = f"%{search}%"
            query = query.filter(
                (Lead.business_name.ilike(search_pattern)) |
                (Lead.phone.ilike(search_pattern))
            )
        
        if candidates_only:
            query = query.filter(Lead.is_candidate == True)
        
        leads = query.all()
        return [LeadResponse.from_orm(lead) for lead in leads]
    finally:
        db.close()


@app.delete("/leads/{lead_id}")
async def delete_lead(lead_id: str):
    """Delete a specific lead by ID"""
    db = SessionLocal()
    try:
        lead = db.query(Lead).filter(Lead.id == lead_id).first()
        if not lead:
            raise HTTPException(status_code=404, detail="Lead not found")
        db.delete(lead)
        db.commit()
        return {"deleted": lead_id, "business_name": lead.business_name}
    finally:
        db.close()


@app.delete("/admin/leads")
async def delete_all_leads():
    """Dangerous: Deletes all leads. Use to clear mock/dev data."""
    db = SessionLocal()
    try:
        count = db.query(Lead).count()
        db.query(Lead).delete()
        db.commit()
        return {"deleted": count}
    finally:
        db.close()


@app.delete("/admin/leads/mock")
async def delete_mock_leads():
    """Delete only mock leads from the database"""
    db = SessionLocal()
    try:
        # Delete leads with 'mock' in the source field
        mock_leads = db.query(Lead).filter(Lead.source.like('%mock%')).all()
        count = len(mock_leads)
        for lead in mock_leads:
            db.delete(lead)
        db.commit()
        return {"deleted": count, "type": "mock"}
    finally:
        db.close()


@app.get("/logs")
async def get_logs(tail: int = 500):
    """Return the last N lines from the server log file."""
    try:
        tail = max(1, min(tail, 5000))
        if not LOG_PATH.exists():
            return {"lines": []}
        with LOG_PATH.open("r", encoding="utf-8", errors="ignore") as f:
            lines = f.readlines()
        return {"lines": [ln.rstrip("\n") for ln in lines[-tail:]]}
    except Exception as e:
        return {"lines": [f"Error reading logs: {e}"]}

@app.get("/jobs/{job_id}/screenshots")
async def get_job_screenshots(job_id: str):
    """Get list of screenshots for a specific job"""
    try:
        import os
        screenshots_dir = Path("/app/screenshots")
        if not screenshots_dir.exists():
            return {"screenshots": []}
        
        # Find all screenshots for this job
        screenshots = []
        for filename in os.listdir(screenshots_dir):
            if filename.startswith(f"job_{job_id}_") and filename.endswith(".png"):
                screenshots.append({
                    "filename": filename,
                    "timestamp": os.path.getmtime(screenshots_dir / filename),
                    "size": os.path.getsize(screenshots_dir / filename)
                })
        
        # Sort by screenshot number (embedded in filename)
        screenshots.sort(key=lambda x: x["filename"])
        
        return {"screenshots": screenshots}
    except Exception as e:
        return {"screenshots": [], "error": str(e)}

@app.get("/screenshots/{filename}")
async def get_screenshot(filename: str):
    """Serve a screenshot image file"""
    try:
        from fastapi.responses import FileResponse
        screenshots_dir = Path("/app/screenshots")
        file_path = screenshots_dir / filename
        
        if not file_path.exists():
            raise HTTPException(status_code=404, detail="Screenshot not found")
        
        return FileResponse(
            file_path,
            media_type="image/png",
            filename=filename
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error serving screenshot: {e}")

@app.websocket("/ws/jobs/{job_id}")
async def websocket_endpoint(websocket: WebSocket, job_id: str):
    await websocket.accept()
    active_connections[job_id].append(websocket)
    
    # Send existing logs
    for log in job_logs.get(job_id, []):
        await websocket.send_json({
            "type": "log",
            "message": log
        })
    
    try:
        # Send job status updates
        while True:
            await asyncio.sleep(1)
            with job_lock:
                if job_id in jobs:
                    await websocket.send_json({
                        "type": "status",
                        "data": jobs[job_id]
                    })
                    if jobs[job_id]["status"] in ["done", "error"]:
                        break
    except WebSocketDisconnect:
        active_connections[job_id].remove(websocket)
    except Exception as e:
        print(f"WebSocket error: {e}")
        if websocket in active_connections[job_id]:
            active_connections[job_id].remove(websocket)


@app.websocket("/ws/logs")
async def websocket_logs(websocket: WebSocket):
    await websocket.accept()
    logs_connections.append(websocket)
    try:
        # On connect, send the last 200 lines
        if LOG_PATH.exists():
            with LOG_PATH.open("r", encoding="utf-8", errors="ignore") as f:
                lines = f.readlines()[-200:]
                for ln in lines:
                    await websocket.send_json({"type": "log", "message": ln.rstrip("\n")})

        # Tail the file for new lines
        last_size = LOG_PATH.stat().st_size if LOG_PATH.exists() else 0
        while True:
            await asyncio.sleep(1)
            if not LOG_PATH.exists():
                continue
            size = LOG_PATH.stat().st_size
            if size > last_size:
                with LOG_PATH.open("r", encoding="utf-8", errors="ignore") as f:
                    f.seek(last_size)
                    chunk = f.read(size - last_size)
                last_size = size
                for ln in chunk.splitlines():
                    await websocket.send_json({"type": "log", "message": ln})
    except WebSocketDisconnect:
        if websocket in logs_connections:
            logs_connections.remove(websocket)
    except Exception as e:
        try:
            await websocket.send_json({"type": "error", "message": str(e)})
        except Exception:
            pass
        if websocket in logs_connections:
            logs_connections.remove(websocket)

@app.get("/leads/{lead_id}", response_model=LeadResponse)
async def get_lead(lead_id: str):
    db = SessionLocal()
    try:
        lead = db.query(Lead).filter(Lead.id == lead_id).first()
        if not lead:
            raise HTTPException(status_code=404, detail="Lead not found")
        return LeadResponse.from_orm(lead)
    finally:
        db.close()


@app.put("/leads/{lead_id}", response_model=LeadResponse)
async def update_lead(lead_id: str, update: LeadUpdate):
    db = SessionLocal()
    try:
        lead = db.query(Lead).filter(Lead.id == lead_id).first()
        if not lead:
            raise HTTPException(status_code=404, detail="Lead not found")
        
        update_data = update.dict(exclude_unset=True)
        for key, value in update_data.items():
            setattr(lead, key, value)
        
        lead.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(lead)
        
        return LeadResponse.from_orm(lead)
    finally:
        db.close()


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
