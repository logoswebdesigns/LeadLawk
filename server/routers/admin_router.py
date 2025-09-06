"""
Admin router for administrative operations.
Pattern: MVC Controller - admin endpoint handling.
Single Responsibility: Administrative operations only.
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import Dict

from ..database import get_db
from ..services.admin_service import AdminService
from ..auth.dependencies import get_admin_user
from ..models import User

router = APIRouter(
    prefix="/admin",
    tags=["admin"],
)


def get_admin_service(db: Session = Depends(get_db)) -> AdminService:
    """Dependency injection for admin service."""
    return AdminService(db)


@router.delete("/leads")
async def delete_all_leads(
    service: AdminService = Depends(get_admin_service),
    admin_user: User = Depends(get_admin_user)
) -> Dict[str, str]:
    """Delete all leads from the database."""
    count = service.delete_all_leads()
    return {"message": f"Deleted {count} leads"}


@router.delete("/leads/mock")
async def delete_mock_leads(
    service: AdminService = Depends(get_admin_service),
    admin_user: User = Depends(get_admin_user)
) -> Dict[str, str]:
    """Delete all mock/test leads."""
    count = service.delete_mock_leads()
    return {"message": f"Deleted {count} mock leads"}


@router.post("/containers/cleanup")
async def cleanup_containers(
    service: AdminService = Depends(get_admin_service),
    admin_user: User = Depends(get_admin_user)
) -> Dict[str, str]:
    """Clean up Docker containers and resources."""
    result = service.cleanup_containers()
    return result


@router.get("/diagnostics")
async def get_diagnostics(
    service: AdminService = Depends(get_admin_service)
) -> Dict[str, any]:
    """Get system diagnostics and health information."""
    return service.get_diagnostics()