"""
PageSpeed router for PageSpeed analysis endpoints.
Pattern: MVC Controller - PageSpeed endpoint handling.
Single Responsibility: PageSpeed analysis operations only.
"""

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import Dict, Any, List

from ..database import get_db
from ..services.pagespeed_service import PageSpeedService

router = APIRouter(
    prefix="/leads/pagespeed",
    tags=["pagespeed"],
)


def get_pagespeed_service(db: Session = Depends(get_db)) -> PageSpeedService:
    """Dependency injection for PageSpeed service."""
    return PageSpeedService(db)


@router.post("/{lead_id}")
async def analyze_lead_pagespeed(
    lead_id: str,
    background_tasks: BackgroundTasks,
    service: PageSpeedService = Depends(get_pagespeed_service)
):
    """Analyze PageSpeed for a specific lead."""
    result = service.analyze_single_lead(lead_id, background_tasks)
    if not result:
        raise HTTPException(status_code=404, detail="Lead not found")
    return result


@router.post("/bulk")
async def analyze_bulk_pagespeed(
    lead_ids: List[str],
    background_tasks: BackgroundTasks,
    service: PageSpeedService = Depends(get_pagespeed_service)
):
    """Analyze PageSpeed for multiple leads."""
    return service.analyze_bulk_leads(lead_ids, background_tasks)


@router.get("/status")
async def get_pagespeed_status(
    service: PageSpeedService = Depends(get_pagespeed_service)
):
    """Get PageSpeed analysis status."""
    return service.get_analysis_status()


@router.get("/missing-count")
async def get_missing_pagespeed_count(
    service: PageSpeedService = Depends(get_pagespeed_service)
):
    """Get count of leads missing PageSpeed scores."""
    return service.get_missing_count()


@router.post("/process-missing")
async def process_missing_pagespeed(
    background_tasks: BackgroundTasks,
    limit: int = 50,
    service: PageSpeedService = Depends(get_pagespeed_service)
):
    """Process leads missing PageSpeed scores."""
    return service.process_missing_scores(background_tasks, limit)