"""
Sales router for sales pitch and email template management.
Pattern: MVC Controller - sales tools endpoint handling.
Single Responsibility: Sales pitch and email template management only.
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from ..database import get_db
from ..services.sales_service import SalesService
from ..schemas import (
    SalesPitchResponse, SalesPitchCreate, SalesPitchUpdate,
    EmailTemplateResponse, EmailTemplateCreate, EmailTemplateUpdate
)

router = APIRouter(tags=["sales"])


def get_sales_service(db: Session = Depends(get_db)) -> SalesService:
    """Dependency injection for sales service."""
    return SalesService(db)


@router.get("/sales-pitches", response_model=List[SalesPitchResponse])
async def get_sales_pitches(
    service: SalesService = Depends(get_sales_service)
):
    """Get all sales pitches."""
    return service.get_all_pitches()


@router.post("/sales-pitches", response_model=SalesPitchResponse)
async def create_sales_pitch(
    pitch: SalesPitchCreate,
    service: SalesService = Depends(get_sales_service)
):
    """Create a new sales pitch."""
    return service.create_pitch(pitch)


@router.put("/sales-pitches/{pitch_id}", response_model=SalesPitchResponse)
async def update_sales_pitch(
    pitch_id: str,
    pitch: SalesPitchUpdate,
    service: SalesService = Depends(get_sales_service)
):
    """Update an existing sales pitch."""
    updated = service.update_pitch(pitch_id, pitch)
    if not updated:
        raise HTTPException(status_code=404, detail="Pitch not found")
    return updated


@router.delete("/sales-pitches/{pitch_id}")
async def delete_sales_pitch(
    pitch_id: str,
    service: SalesService = Depends(get_sales_service)
):
    """Delete a sales pitch."""
    if not service.delete_pitch(pitch_id):
        raise HTTPException(status_code=404, detail="Pitch not found")
    return {"message": "Pitch deleted successfully"}


@router.post("/leads/{lead_id}/assign-pitch")
async def assign_pitch_to_lead(
    lead_id: str,
    pitch_id: str,
    service: SalesService = Depends(get_sales_service)
):
    """Assign a sales pitch to a lead."""
    if not service.assign_pitch_to_lead(lead_id, pitch_id):
        raise HTTPException(status_code=404, detail="Lead or pitch not found")
    return {"message": "Pitch assigned successfully"}


@router.get("/sales-pitches/analytics")
async def get_pitch_analytics(
    service: SalesService = Depends(get_sales_service)
):
    """Get analytics for sales pitches."""
    return service.get_pitch_analytics()


@router.get("/email-templates", response_model=List[EmailTemplateResponse])
async def get_email_templates(
    service: SalesService = Depends(get_sales_service)
):
    """Get all email templates."""
    return service.get_all_templates()


@router.get("/email-templates/{template_id}", response_model=EmailTemplateResponse)
async def get_email_template(
    template_id: str,
    service: SalesService = Depends(get_sales_service)
):
    """Get a specific email template."""
    template = service.get_template_by_id(template_id)
    if not template:
        raise HTTPException(status_code=404, detail="Template not found")
    return template


@router.post("/email-templates", response_model=EmailTemplateResponse)
async def create_email_template(
    template: EmailTemplateCreate,
    service: SalesService = Depends(get_sales_service)
):
    """Create a new email template."""
    return service.create_template(template)


@router.put("/email-templates/{template_id}", response_model=EmailTemplateResponse)
async def update_email_template(
    template_id: str,
    template: EmailTemplateUpdate,
    service: SalesService = Depends(get_sales_service)
):
    """Update an email template."""
    updated = service.update_template(template_id, template)
    if not updated:
        raise HTTPException(status_code=404, detail="Template not found")
    return updated


@router.delete("/email-templates/{template_id}")
async def delete_email_template(
    template_id: str,
    service: SalesService = Depends(get_sales_service)
):
    """Delete an email template."""
    if not service.delete_template(template_id):
        raise HTTPException(status_code=404, detail="Template not found")
    return {"message": "Template deleted successfully"}


@router.post("/email-templates/initialize-defaults")
async def initialize_default_templates(
    service: SalesService = Depends(get_sales_service)
):
    """Initialize default email templates."""
    count = service.initialize_default_templates()
    return {"message": f"Created {count} default templates"}