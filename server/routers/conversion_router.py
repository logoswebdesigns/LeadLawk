"""
Conversion router for lead conversion tracking endpoints.
Pattern: MVC Controller - conversion tracking endpoint handling.
Single Responsibility: Conversion tracking and scoring only.
"""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import Dict, Any, List

from ..database import get_db
from ..services.conversion_service import ConversionService
from ..schemas import ConversionModelResponse, ConversionScoringResponse
from ..auth.dependencies import get_current_user
from ..models import User

router = APIRouter(
    prefix="/conversion",
    tags=["conversion"],
)


def get_conversion_service(db: Session = Depends(get_db)) -> ConversionService:
    """Dependency injection for conversion service."""
    return ConversionService(db)


@router.post("/train", response_model=ConversionModelResponse)
async def train_conversion_model(
    service: ConversionService = Depends(get_conversion_service),
    current_user: User = Depends(get_current_user)
):
    """Train the conversion prediction model."""
    return service.train_model()


@router.post("/calculate", response_model=ConversionScoringResponse)
async def calculate_conversion_scores(
    service: ConversionService = Depends(get_conversion_service),
    current_user: User = Depends(get_current_user)
):
    """Calculate conversion scores for all leads."""
    return service.calculate_scores()


@router.get("/stats", response_model=ConversionModelResponse)
async def get_conversion_stats(
    service: ConversionService = Depends(get_conversion_service),
    current_user: User = Depends(get_current_user)
):
    """Get conversion model statistics."""
    return service.get_model_stats()


@router.get("/leads/top-converting")
async def get_top_converting_leads(
    limit: int = 20,
    service: ConversionService = Depends(get_conversion_service),
    current_user: User = Depends(get_current_user)
):
    """Get leads with highest conversion probability."""
    return service.get_top_converting_leads(limit)