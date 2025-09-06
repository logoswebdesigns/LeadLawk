"""
Lead Repository implementing the Repository Pattern.
Encapsulates all data access logic and provides a clean interface.
"""

from typing import List, Optional, Dict, Any
from sqlalchemy.orm import Session, selectinload
from sqlalchemy import func
from datetime import datetime

from ..models import Lead, LeadTimelineEntry, CallLog
from ..core.pagination import (
    PaginationParams, 
    SortParams, 
    PaginatedResponse, 
    PaginationService,
    Specification
)
from ..schemas import LeadCreate, LeadUpdate


class LeadRepository:
    """
    Repository for Lead entity following Domain-Driven Design principles.
    Provides a collection-like interface for accessing leads.
    """
    
    # Field mapping for sorting
    SORT_FIELD_MAP = {
        "created_at": Lead.created_at,
        "updated_at": Lead.updated_at,
        "business_name": Lead.business_name,
        "rating": Lead.rating,
        "review_count": Lead.review_count,
        "status": Lead.status,
        "location": Lead.location,
        "industry": Lead.industry,
        "pagespeed_mobile_score": Lead.pagespeed_mobile_score,
        "pagespeed_desktop_score": Lead.pagespeed_desktop_score,
        "conversion_score": Lead.conversion_score,
        "follow_up_date": Lead.follow_up_date,
    }
    
    def __init__(self, session: Session):
        """Initialize repository with database session."""
        self.session = session
    
    def find_by_id(self, lead_id: str) -> Optional[Lead]:
        """
        Find a lead by ID with related data.
        
        Args:
            lead_id: The lead's unique identifier
            
        Returns:
            Lead entity or None if not found
        """
        return self.session.query(Lead).options(
            selectinload(Lead.timeline_entries),
            selectinload(Lead.call_logs),
            selectinload(Lead.sales_pitch)
        ).filter(Lead.id == lead_id).first()
    
    def find_by_phone(self, phone: str) -> Optional[Lead]:
        """
        Find a lead by phone number.
        
        Args:
            phone: Phone number to search
            
        Returns:
            Lead entity or None if not found
        """
        return self.session.query(Lead).filter(Lead.phone == phone).first()
    
    def find_all(
        self,
        pagination: PaginationParams,
        sort: Optional[SortParams] = None,
        specifications: Optional[List[Specification]] = None
    ) -> PaginatedResponse[Lead]:
        """
        Find all leads with pagination, sorting, and filtering.
        
        Args:
            pagination: Pagination parameters
            sort: Optional sorting parameters
            specifications: Optional list of filter specifications
            
        Returns:
            Paginated response with leads
        """
        query = self._base_query()
        
        # Apply default sort if not specified
        if not sort:
            sort = SortParams(field="created_at", ascending=False, nulls_position="last")
        
        return PaginationService.paginate(
            query=query,
            pagination=pagination,
            sort=sort,
            specifications=specifications,
            field_map=self.SORT_FIELD_MAP
        )
    
    def count(self, specifications: Optional[List[Specification]] = None) -> int:
        """
        Count leads matching specifications.
        
        Args:
            specifications: Optional list of filter specifications
            
        Returns:
            Count of matching leads
        """
        query = self.session.query(func.count(Lead.id))
        
        if specifications:
            for spec in specifications:
                query = spec.apply(query)
        
        return query.scalar()
    
    def exists(self, lead_id: str) -> bool:
        """
        Check if a lead exists.
        
        Args:
            lead_id: The lead's unique identifier
            
        Returns:
            True if lead exists, False otherwise
        """
        return self.session.query(
            self.session.query(Lead).filter(Lead.id == lead_id).exists()
        ).scalar()
    
    def save(self, lead: Lead) -> Lead:
        """
        Save a lead (create or update).
        
        Args:
            lead: Lead entity to save
            
        Returns:
            Saved lead entity
        """
        self.session.add(lead)
        self.session.flush()  # Flush to get ID without committing
        return lead
    
    def create(self, lead_data: LeadCreate) -> Lead:
        """
        Create a new lead.
        
        Args:
            lead_data: Lead creation data
            
        Returns:
            Created lead entity
        """
        lead = Lead(**lead_data.dict())
        return self.save(lead)
    
    def update(self, lead_id: str, lead_data: LeadUpdate) -> Optional[Lead]:
        """
        Update an existing lead.
        
        Args:
            lead_id: The lead's unique identifier
            lead_data: Lead update data
            
        Returns:
            Updated lead entity or None if not found
        """
        lead = self.find_by_id(lead_id)
        if not lead:
            return None
        
        # Update fields
        update_data = lead_data.dict(exclude_unset=True)
        for field, value in update_data.items():
            setattr(lead, field, value)
        
        lead.updated_at = datetime.utcnow()
        return self.save(lead)
    
    def delete(self, lead_id: str) -> bool:
        """
        Delete a lead.
        
        Args:
            lead_id: The lead's unique identifier
            
        Returns:
            True if deleted, False if not found
        """
        lead = self.find_by_id(lead_id)
        if not lead:
            return False
        
        self.session.delete(lead)
        return True
    
    def delete_many(self, lead_ids: List[str]) -> int:
        """
        Delete multiple leads.
        
        Args:
            lead_ids: List of lead IDs to delete
            
        Returns:
            Number of leads deleted
        """
        count = self.session.query(Lead).filter(
            Lead.id.in_(lead_ids)
        ).delete(synchronize_session=False)
        return count
    
    def get_statistics(self) -> Dict[str, Any]:
        """
        Get lead statistics grouped by status.
        
        Returns:
            Dictionary with statistics
        """
        stats = self.session.query(
            Lead.status,
            func.count(Lead.id).label('count')
        ).group_by(Lead.status).all()
        
        total = sum(s.count for s in stats)
        by_status = {s.status: s.count for s in stats}
        
        # Additional statistics
        candidates_count = self.session.query(func.count(Lead.id)).filter(
            Lead.is_candidate == True
        ).scalar()
        
        with_website_count = self.session.query(func.count(Lead.id)).filter(
            Lead.website_url.isnot(None)
        ).scalar()
        
        pagespeed_tested_count = self.session.query(func.count(Lead.id)).filter(
            Lead.pagespeed_tested_at.isnot(None)
        ).scalar()
        
        return {
            "total": total,
            "by_status": by_status,
            "candidates": candidates_count,
            "with_website": with_website_count,
            "pagespeed_tested": pagespeed_tested_count,
            "conversion_rate": self._calculate_conversion_rate(by_status, total)
        }
    
    def _base_query(self):
        """Get base query with common eager loading."""
        return self.session.query(Lead).options(
            selectinload(Lead.timeline_entries),
            selectinload(Lead.call_logs),
            selectinload(Lead.sales_pitch)
        )
    
    def _calculate_conversion_rate(self, by_status: Dict, total: int) -> float:
        """Calculate conversion rate from status statistics."""
        if total == 0:
            return 0.0
        converted = by_status.get('converted', 0)
        return (converted / total) * 100