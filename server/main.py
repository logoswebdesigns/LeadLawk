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

app = FastAPI(title="LeadLawk API")

# Configure logging to a rotating file
LOG_PATH = Path(__file__).resolve().parent / "server.log"
LOG_PATH.parent.mkdir(parents=True, exist_ok=True)

logger = logging.getLogger("leadlawk")
logger.setLevel(logging.INFO)
_handler = RotatingFileHandler(LOG_PATH, maxBytes=1_000_000, backupCount=3)
_formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
_handler.setFormatter(_formatter)
if not any(isinstance(h, RotatingFileHandler) for h in logger.handlers):
    logger.addHandler(_handler)

# Also forward uvicorn logs to the same file
for _name in ("uvicorn", "uvicorn.error", "uvicorn.access"):
    _uv = logging.getLogger(_name)
    if not any(isinstance(h, RotatingFileHandler) for h in _uv.handlers):
        _uv.addHandler(_handler)

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
            
def add_job_log(job_id: str, log_message: str):
    timestamp = datetime.utcnow().isoformat()
    formatted_log = f"[{timestamp}] {log_message}"
    job_logs[job_id].append(formatted_log)
    # Persist to server log as well
    try:
      logger.info(f"JOB {job_id}: {log_message}")
    except Exception:
      pass
    # Send to connected WebSocket clients
    try:
        # If we're on the event loop thread
        asyncio.get_running_loop()
        asyncio.create_task(broadcast_log(job_id, formatted_log))
    except RuntimeError:
        # Called from a background thread: submit to main loop
        if event_loop is not None:
            asyncio.run_coroutine_threadsafe(broadcast_log(job_id, formatted_log), event_loop)
    
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
    try:
        update_job_status(job_id, "running", 0, params.limit)
        add_job_log(job_id, f"Starting scrape for {params.industry} in {params.location}")
        add_job_log(job_id, f"Search parameters: {params.limit} leads, min rating {params.min_rating}, min reviews {params.min_reviews}")
        add_job_log(job_id, f"Python: {sys.executable}")
        add_job_log(job_id, f"USE_MOCK_DATA={os.environ.get('USE_MOCK_DATA')}")

        # If real scraper prerequisites are missing, automatically enable mock mode
        enable_mock = False
        try:
            import selenium  # noqa: F401
            has_selenium = True
        except Exception:
            has_selenium = False
        chromedriver = shutil.which("chromedriver")
        if not has_selenium or not chromedriver:
            # Respect explicit env override if user already set USE_MOCK_DATA
            if (os.environ.get("USE_MOCK_DATA") or "").lower() not in ("true", "1", "yes"):
                enable_mock = True
                add_job_log(job_id, "Selenium/driver not available. Enabling USE_MOCK_DATA=true for this run.")
        
        cmd = [
            sys.executable,
            "-m", "scrapy", "runspider",
            "scraper/gmaps_spider.py",
            "-a", f"industry={params.industry}",
            "-a", f"location={params.location}",
            "-a", f"limit={params.limit}",
            "-a", f"min_rating={params.min_rating}",
            "-a", f"min_reviews={params.min_reviews}",
            "-a", f"recent_days={params.recent_days}",
            "-a", f"job_id={job_id}",
            "-L", "INFO"
        ]
        
        add_job_log(job_id, f"Launching Scrapy spider... CWD={Path.cwd()} CMD={' '.join(cmd)}")
        
        # Prepare environment for child process (optionally enabling mock data)
        child_env = os.environ.copy()
        if enable_mock:
            child_env["USE_MOCK_DATA"] = "true"
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            env=child_env
        )
        
        # Stream output line by line
        for line in iter(process.stdout.readline, ''):
            if line:
                add_job_log(job_id, line.strip())
        
        process.wait()
        
        # Determine outcome based on process return code and progress tracked during run
        processed = 0
        with job_lock:
            if job_id in jobs:
                processed = int(jobs[job_id].get("processed", 0) or 0)
        if process.returncode == 0 and processed > 0:
            add_job_log(job_id, f"Scrape completed successfully! Processed {processed} leads.")
            update_job_status(job_id, "done", processed, params.limit)
        else:
            # Craft a concise, actionable error message with context
            with job_lock:
                tail = job_logs.get(job_id, [])[-5:]
            tail_preview = " | ".join(tail)[:400] if tail else "(no output captured)"
            msg = (
                f"Scraper exited with code {process.returncode}. "
                f"Processed {processed} of {params.limit}. "
                f"Last output: {tail_preview}"
            )
            add_job_log(job_id, "Scrape failed or produced no results")
            update_job_status(job_id, "error", processed, params.limit, msg)
            
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
    # Scrapy availability
    try:
        import scrapy  # noqa: F401
        msgs.append("Scrapy: OK")
    except Exception as e:
        ok = False
        msgs.append(f"Scrapy import failed: {e}")
    # Selenium availability (for real scraper)
    try:
        import selenium  # noqa: F401
        msgs.append("Selenium: OK")
    except Exception as e:
        msgs.append(f"Selenium import failed (real scraper disabled): {e}")
    # ChromeDriver on PATH
    chromedriver = shutil.which("chromedriver")
    if chromedriver:
        msgs.append(f"chromedriver: {chromedriver}")
    else:
        msgs.append("chromedriver not found on PATH (required for real scraper)")
    return ok, msgs


@app.get("/jobs/{job_id}", response_model=JobResponse)
async def get_job_status(job_id: str):
    with job_lock:
        if job_id not in jobs:
            raise HTTPException(status_code=404, detail="Job not found")
        return JobResponse(**jobs[job_id])


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
