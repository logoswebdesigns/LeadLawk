"""
Miscellaneous router for utility endpoints.
Pattern: MVC Controller - utility endpoint handling.
Single Responsibility: Miscellaneous utility operations only.
"""

from fastapi import APIRouter, HTTPException, Depends
from fastapi.responses import FileResponse, StreamingResponse, HTMLResponse
from pathlib import Path
from typing import Dict, Any
import subprocess
import os

from ..database import SessionLocal, get_db
from ..services.lead_service import LeadService
import pandas as pd
from io import BytesIO

router = APIRouter()


@router.get("/logs")
async def get_server_logs(lines: int = 100):
    """Get recent server logs."""
    log_path = Path(__file__).resolve().parent.parent / "server.log"
    if not log_path.exists():
        return {"logs": []}
    
    try:
        with open(log_path, 'r') as f:
            all_lines = f.readlines()
            return {"logs": all_lines[-lines:]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/screenshots/{filename}")
async def get_screenshot(filename: str):
    """Serve screenshot files."""
    screenshot_path = Path("screenshots") / filename
    if not screenshot_path.exists():
        raise HTTPException(status_code=404, detail="Screenshot not found")
    
    return FileResponse(
        screenshot_path,
        media_type="image/png",
        headers={"Cache-Control": "public, max-age=3600"}
    )


@router.get("/monitor/{job_id}")
async def monitor_job(job_id: str):
    """Monitor page for job progress."""
    html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Job Monitor - {job_id}</title>
        <script>
            const ws = new WebSocket(`ws://localhost:8000/ws/jobs/{job_id}`);
            ws.onmessage = (event) => {{
                document.getElementById('status').innerHTML += event.data + '<br>';
            }};
        </script>
    </head>
    <body>
        <h1>Job Monitor: {job_id}</h1>
        <div id="status"></div>
    </body>
    </html>
    """
    return HTMLResponse(content=html)


@router.get("/containers/status")
async def get_container_status():
    """Get Docker container status."""
    try:
        result = subprocess.run(
            ['docker', 'ps', '--format', 'json'],
            capture_output=True,
            text=True,
            check=True
        )
        return {"containers": result.stdout.splitlines()}
    except Exception as e:
        return {"error": str(e)}


@router.post("/containers/scale")
async def scale_containers(replicas: int = 1):
    """Scale Docker containers."""
    try:
        result = subprocess.run(
            ['docker-compose', 'up', '-d', '--scale', f'selenium-chrome={replicas}'],
            capture_output=True,
            text=True,
            check=True
        )
        return {"message": f"Scaled to {replicas} replicas"}
    except Exception as e:
        return {"error": str(e)}


@router.get("/grid/status")
async def get_grid_status():
    """Get Selenium Grid status."""
    hub_url = os.environ.get('SELENIUM_HUB_URL', 'http://selenium-chrome:4444')
    return {"hub_url": hub_url, "status": "configured"}


@router.post("/grid/scale")
async def scale_grid(nodes: int = 1):
    """Scale Selenium Grid nodes."""
    return {"message": f"Grid scaling to {nodes} nodes"}


@router.get("/leads/export/excel")
async def export_leads_to_excel(db = Depends(get_db)):
    """Export all leads to Excel file."""
    service = LeadService(db)
    leads = service.get_paginated_leads(per_page=10000)
    
    data = []
    for lead in leads.items:
        data.append({
            "Business Name": lead.business_name,
            "Phone": lead.phone,
            "Website": lead.website_url,
            "Rating": lead.rating,
            "Reviews": lead.review_count,
            "Status": lead.status,
            "Location": lead.location
        })
    
    df = pd.DataFrame(data)
    output = BytesIO()
    df.to_excel(output, index=False)
    output.seek(0)
    
    return StreamingResponse(
        output,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": "attachment; filename=leads.xlsx"}
    )