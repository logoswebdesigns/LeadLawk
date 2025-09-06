"""
Lead service for business logic.
Pattern: Service Layer Pattern - encapsulates business logic.
Single Responsibility: Lead management operations only.
"""

from typing import List, Optional, Dict, Any
from sqlalchemy.orm import Session, selectinload
from sqlalchemy import and_, or_, func
from datetime import datetime, timedelta
import logging

from ..models import Lead, LeadTimelineEntry, CallLog
from ..schemas import LeadCreate, LeadUpdate, PaginatedResponse

logger = logging.getLogger(__name__)


class LeadService:
    """
    Service class for lead operations.
    Dependency Injection: Database session injected via constructor.
    """
    
    def __init__(self, db: Session):
        self.db = db
    
    def get_paginated_leads(
        self,
        page: int = 1,
        per_page: int = 50,
        status: Optional[str] = None,
        search: Optional[str] = None,
        sort_by: str = "created_at",
        sort_ascending: bool = False
    ) -> PaginatedResponse:
        """Get paginated list of leads with filtering and sorting."""
        query = self.db.query(Lead).options(
            selectinload(Lead.timeline_entries),
            selectinload(Lead.call_logs)
        )
        
        if status:
            # Map Flutter's 'new_' to database 'new' (new is reserved in Dart)
            logger.info(f"Filtering by status: '{status}'")
            if status == 'new_':
                logger.info("Mapping 'new_' to 'new' for database query")
                # Use the string 'new' directly for the database query
                query = query.filter(Lead.status == 'new')
            else:
                query = query.filter(Lead.status == status)
        
        if search:
            search_term = f"%{search}%"
            query = query.filter(
                or_(
                    Lead.business_name.ilike(search_term),
                    Lead.phone.ilike(search_term),
                    Lead.location.ilike(search_term)
                )
            )
        
        total = query.count()
        
        sort_column = getattr(Lead, sort_by, Lead.created_at)
        query = query.order_by(
            sort_column.asc() if sort_ascending else sort_column.desc()
        )
        
        leads = query.offset((page - 1) * per_page).limit(per_page).all()
        
        return PaginatedResponse(
            items=leads,
            total=total,
            page=page,
            per_page=per_page,
            total_pages=(total + per_page - 1) // per_page
        )
    
    def get_lead_by_id(self, lead_id: str) -> Optional[Lead]:
        """Get a single lead by ID."""
        return self.db.query(Lead).options(
            selectinload(Lead.timeline_entries),
            selectinload(Lead.call_logs)
        ).filter(Lead.id == lead_id).first()
    
    def create_lead(self, lead_data: LeadCreate) -> Lead:
        """Create a new lead."""
        lead = Lead(**lead_data.dict())
        self.db.add(lead)
        self.db.commit()
        self.db.refresh(lead)
        return lead
    
    def update_lead(self, lead_id: str, lead_data: LeadUpdate) -> Optional[Lead]:
        """Update an existing lead."""
        lead = self.get_lead_by_id(lead_id)
        if not lead:
            return None
        
        for key, value in lead_data.dict(exclude_unset=True).items():
            setattr(lead, key, value)
        
        self.db.commit()
        self.db.refresh(lead)
        return lead
    
    def delete_lead(self, lead_id: str) -> bool:
        """Delete a lead and all related data."""
        lead = self.get_lead_by_id(lead_id)
        if not lead:
            return False
        
        self.db.delete(lead)
        self.db.commit()
        return True
    
    def get_statistics(self) -> Dict[str, Any]:
        """Get lead statistics grouped by status."""
        stats = self.db.query(
            Lead.status,
            func.count(Lead.id).label('count')
        ).group_by(Lead.status).all()
        
        return {
            "total": sum(s.count for s in stats),
            "by_status": {s.status: s.count for s in stats}
        }
    
    def get_leads_called_today(self) -> List[Lead]:
        """Get leads that were called today."""
        today = datetime.now().date()
        return self.db.query(Lead).join(CallLog).filter(
            func.date(CallLog.created_at) == today
        ).distinct().all()