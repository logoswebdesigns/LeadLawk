"""
Analytics router for data analysis endpoints.
Pattern: MVC Controller - analytics endpoint handling.
Single Responsibility: Analytics and reporting only.
"""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import Dict, Any

from ..database import get_db
from ..services.analytics_service import AnalyticsService

router = APIRouter(
    prefix="/analytics",
    tags=["analytics"],
)


def get_analytics_service(db: Session = Depends(get_db)) -> AnalyticsService:
    """Dependency injection for analytics service."""
    return AnalyticsService(db)


@router.get("/overview")
async def get_analytics_overview(
    service: AnalyticsService = Depends(get_analytics_service)
) -> Dict[str, Any]:
    """Get analytics overview."""
    return service.get_overview()


@router.get("/segments")
async def get_analytics_segments(
    service: AnalyticsService = Depends(get_analytics_service)
) -> Dict[str, Any]:
    """Get segmented analytics data."""
    return service.get_segments()


@router.get("/timeline")
async def get_analytics_timeline(
    service: AnalyticsService = Depends(get_analytics_service)
) -> Dict[str, Any]:
    """Get timeline analytics."""
    return service.get_timeline()


@router.get("/insights")
async def get_analytics_insights(
    service: AnalyticsService = Depends(get_analytics_service)
) -> Dict[str, Any]:
    """Get AI-generated insights."""
    return service.get_insights()