"""
Leads router for API endpoints.
Pattern: MVC Controller pattern - thin controllers, fat services.
Single Responsibility: HTTP request/response handling only.
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import Optional, List

from ..database import get_db
from ..services.lead_service import LeadService
from ..auth.dependencies import get_current_user
from ..models import User
from ..schemas import (
    LeadResponse, 
    LeadCreate, 
    LeadUpdate,
    PaginatedLeadsResponse,
    LeadStatisticsResponse
)

router = APIRouter(
    prefix="/leads",
    tags=["leads"],
)


def get_lead_service(db: Session = Depends(get_db)) -> LeadService:
    """Dependency injection for lead service."""
    return LeadService(db)


@router.get("", response_model=PaginatedLeadsResponse)
async def get_leads(
    page: int = Query(1, ge=1),
    per_page: int = Query(50, ge=1, le=100),
    status: Optional[str] = None,
    search: Optional[str] = None,
    sort_by: str = "created_at",
    sort_ascending: bool = False,
    service: LeadService = Depends(get_lead_service),
    current_user: User = Depends(get_current_user)
):
    """Get paginated list of leads."""
    return service.get_paginated_leads(
        page=page,
        per_page=per_page,
        status=status,
        search=search,
        sort_by=sort_by,
        sort_ascending=sort_ascending
    )


@router.get("/statistics/all", response_model=LeadStatisticsResponse)
async def get_statistics(service: LeadService = Depends(get_lead_service), current_user: User = Depends(get_current_user)):
    """Get lead statistics grouped by status."""
    return service.get_statistics()


@router.get("/called-today", response_model=List[LeadResponse])
async def get_leads_called_today(service: LeadService = Depends(get_lead_service), current_user: User = Depends(get_current_user)):
    """Get leads that were called today."""
    return service.get_leads_called_today()


@router.get("/{lead_id}", response_model=LeadResponse)
async def get_lead(
    lead_id: str,
    service: LeadService = Depends(get_lead_service),
    current_user: User = Depends(get_current_user)
):
    """Get a single lead by ID."""
    lead = service.get_lead_by_id(lead_id)
    if not lead:
        raise HTTPException(status_code=404, detail="Lead not found")
    return lead


@router.post("", response_model=LeadResponse)
async def create_lead(
    lead: LeadCreate,
    service: LeadService = Depends(get_lead_service),
    current_user: User = Depends(get_current_user)
):
    """Create a new lead."""
    return service.create_lead(lead)


@router.put("/{lead_id}", response_model=LeadResponse)
async def update_lead(
    lead_id: str,
    lead: LeadUpdate,
    service: LeadService = Depends(get_lead_service),
    current_user: User = Depends(get_current_user)
):
    """Update an existing lead."""
    updated_lead = service.update_lead(lead_id, lead)
    if not updated_lead:
        raise HTTPException(status_code=404, detail="Lead not found")
    return updated_lead


@router.delete("/{lead_id}")
async def delete_lead(
    lead_id: str,
    service: LeadService = Depends(get_lead_service),
    current_user: User = Depends(get_current_user)
):
    """Delete a lead."""
    if not service.delete_lead(lead_id):
        raise HTTPException(status_code=404, detail="Lead not found")
    return {"message": "Lead deleted successfully"}