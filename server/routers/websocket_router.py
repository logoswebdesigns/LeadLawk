"""
WebSocket router for real-time communications.
Pattern: MVC Controller - WebSocket endpoint handling.
Single Responsibility: WebSocket connections only.
"""

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
import logging

from ..websocket_manager import (
    job_websocket_manager,
    log_websocket_manager,
    pagespeed_websocket_manager
)

router = APIRouter()
logger = logging.getLogger(__name__)


@router.websocket("/ws/jobs/{job_id}")
async def job_websocket(websocket: WebSocket, job_id: str):
    """WebSocket endpoint for job status updates."""
    await job_websocket_manager.connect(job_id, websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        job_websocket_manager.disconnect(job_id, websocket)


@router.websocket("/ws/logs")
async def logs_websocket(websocket: WebSocket):
    """WebSocket endpoint for real-time log streaming."""
    await log_websocket_manager.connect("global", websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        log_websocket_manager.disconnect("global", websocket)


@router.websocket("/ws/pagespeed")
async def pagespeed_websocket(websocket: WebSocket):
    """WebSocket endpoint for PageSpeed analysis updates."""
    await pagespeed_websocket_manager.connect("pagespeed", websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        pagespeed_websocket_manager.disconnect("pagespeed", websocket)