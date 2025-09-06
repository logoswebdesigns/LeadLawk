"""
Sales service for sales pitch and email template management.
Pattern: Service Layer Pattern - encapsulates sales logic.
Single Responsibility: Sales tools management only.
"""

from typing import List, Optional, Dict, Any
from sqlalchemy.orm import Session
from sqlalchemy import func
import uuid
from datetime import datetime

from ..models import SalesPitch, EmailTemplate, Lead
from ..schemas import (
    SalesPitchCreate, SalesPitchUpdate,
    EmailTemplateCreate, EmailTemplateUpdate
)


class SalesService:
    """
    Service class for sales operations.
    Pattern: Repository Pattern for data access.
    """
    
    def __init__(self, db: Session):
        self.db = db
    
    def get_all_pitches(self) -> List[SalesPitch]:
        """Get all sales pitches."""
        return self.db.query(SalesPitch).order_by(SalesPitch.name).all()
    
    def create_pitch(self, pitch_data: SalesPitchCreate) -> SalesPitch:
        """Create a new sales pitch."""
        pitch = SalesPitch(
            id=str(uuid.uuid4()),
            **pitch_data.dict()
        )
        self.db.add(pitch)
        self.db.commit()
        self.db.refresh(pitch)
        return pitch
    
    def update_pitch(
        self, pitch_id: str, pitch_data: SalesPitchUpdate
    ) -> Optional[SalesPitch]:
        """Update an existing sales pitch."""
        pitch = self.db.query(SalesPitch).filter(
            SalesPitch.id == pitch_id
        ).first()
        if not pitch:
            return None
        
        for key, value in pitch_data.dict(exclude_unset=True).items():
            setattr(pitch, key, value)
        
        self.db.commit()
        self.db.refresh(pitch)
        return pitch
    
    def delete_pitch(self, pitch_id: str) -> bool:
        """Delete a sales pitch."""
        pitch = self.db.query(SalesPitch).filter(
            SalesPitch.id == pitch_id
        ).first()
        if not pitch:
            return False
        
        self.db.delete(pitch)
        self.db.commit()
        return True
    
    def assign_pitch_to_lead(
        self, lead_id: str, pitch_id: str
    ) -> bool:
        """Assign a sales pitch to a lead."""
        lead = self.db.query(Lead).filter(Lead.id == lead_id).first()
        pitch = self.db.query(SalesPitch).filter(
            SalesPitch.id == pitch_id
        ).first()
        
        if not lead or not pitch:
            return False
        
        lead.sales_pitch_id = pitch_id
        self.db.commit()
        return True
    
    def get_pitch_analytics(self) -> Dict[str, Any]:
        """Get analytics for sales pitches."""
        pitch_usage = self.db.query(
            SalesPitch.id,
            SalesPitch.name,
            func.count(Lead.id).label('lead_count')
        ).outerjoin(Lead).group_by(SalesPitch.id).all()
        
        return {
            "pitches": [
                {
                    "id": p.id,
                    "name": p.name,
                    "lead_count": p.lead_count
                }
                for p in pitch_usage
            ],
            "total_pitches": len(pitch_usage)
        }
    
    def get_all_templates(self) -> List[EmailTemplate]:
        """Get all email templates."""
        return self.db.query(EmailTemplate).order_by(
            EmailTemplate.created_at.desc()
        ).all()
    
    def get_template_by_id(self, template_id: str) -> Optional[EmailTemplate]:
        """Get a specific email template."""
        return self.db.query(EmailTemplate).filter(
            EmailTemplate.id == template_id
        ).first()
    
    def create_template(
        self, template_data: EmailTemplateCreate
    ) -> EmailTemplate:
        """Create a new email template."""
        template = EmailTemplate(
            id=str(uuid.uuid4()),
            **template_data.dict(),
            created_at=datetime.utcnow()
        )
        self.db.add(template)
        self.db.commit()
        self.db.refresh(template)
        return template
    
    def update_template(
        self, template_id: str, template_data: EmailTemplateUpdate
    ) -> Optional[EmailTemplate]:
        """Update an email template."""
        template = self.get_template_by_id(template_id)
        if not template:
            return None
        
        for key, value in template_data.dict(exclude_unset=True).items():
            setattr(template, key, value)
        
        self.db.commit()
        self.db.refresh(template)
        return template
    
    def delete_template(self, template_id: str) -> bool:
        """Delete an email template."""
        template = self.get_template_by_id(template_id)
        if not template:
            return False
        
        self.db.delete(template)
        self.db.commit()
        return True
    
    def initialize_default_templates(self) -> int:
        """Initialize default email templates."""
        defaults = [
            {
                "name": "Initial Outreach",
                "subject": "Grow Your Business Online",
                "body": "Default template content..."
            },
            {
                "name": "Follow Up",
                "subject": "Following Up",
                "body": "Follow up template content..."
            }
        ]
        
        count = 0
        for template_data in defaults:
            existing = self.db.query(EmailTemplate).filter(
                EmailTemplate.name == template_data["name"]
            ).first()
            if not existing:
                template = EmailTemplate(
                    id=str(uuid.uuid4()),
                    **template_data,
                    created_at=datetime.utcnow()
                )
                self.db.add(template)
                count += 1
        
        self.db.commit()
        return count