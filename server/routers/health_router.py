"""
Health and system monitoring endpoints.
Pattern: Health Check Pattern for microservices.
Single Responsibility: System health monitoring only.
"""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from datetime import datetime
from typing import Dict, Any

from ..database import get_db
from ..models import Lead

router = APIRouter(
    prefix="/health",
    tags=["health"],
)


@router.get("")
async def health_check(db: Session = Depends(get_db)) -> Dict[str, Any]:
    """
    Health check endpoint for monitoring.
    Returns system status and basic metrics.
    """
    try:
        lead_count = db.query(Lead).count()
        db_status = "connected"
    except Exception as e:
        lead_count = 0
        db_status = f"error: {str(e)}"
    
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "database": db_status,
        "leads_count": lead_count,
        "version": "1.0.0"
    }


@router.get("/ready")
async def readiness_check(db: Session = Depends(get_db)) -> Dict[str, str]:
    """
    Readiness probe for Kubernetes/Docker deployments.
    Checks if the application is ready to serve traffic.
    """
    try:
        db.execute("SELECT 1")
        return {"status": "ready"}
    except Exception:
        return {"status": "not_ready"}