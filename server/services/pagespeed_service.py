"""
PageSpeed service for website performance analysis.
Pattern: Service Layer Pattern - encapsulates PageSpeed logic.
Single Responsibility: PageSpeed analysis operations only.
"""

from typing import Dict, Any, List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import and_
from fastapi import BackgroundTasks
import logging

from ..models import Lead, LeadStatus
from ..pagespeed_analyzer import analyze_pagespeed_batch, analyze_lead_pagespeed
from ..websocket_manager import pagespeed_websocket_manager

logger = logging.getLogger(__name__)


class PageSpeedService:
    """
    Service class for PageSpeed operations.
    Pattern: Facade Pattern for PageSpeed analysis.
    """
    
    def __init__(self, db: Session):
        self.db = db
    
    def analyze_single_lead(
        self,
        lead_id: str,
        background_tasks: BackgroundTasks
    ) -> Optional[Dict[str, Any]]:
        """Analyze PageSpeed for a single lead."""
        lead = self.db.query(Lead).filter(Lead.id == lead_id).first()
        if not lead:
            return None
        
        if not lead.website_url:
            return {"error": "Lead has no website URL"}
        
        background_tasks.add_task(analyze_lead_pagespeed, lead_id)
        
        return {
            "message": f"Started PageSpeed analysis for {lead.business_name}",
            "lead_id": lead_id,
            "website": lead.website_url
        }
    
    def analyze_bulk_leads(
        self,
        lead_ids: List[str],
        background_tasks: BackgroundTasks
    ) -> Dict[str, Any]:
        """Analyze PageSpeed for multiple leads."""
        leads = self.db.query(Lead).filter(
            Lead.id.in_(lead_ids)
        ).all()
        
        valid_leads = [l for l in leads if l.website_url]
        
        if valid_leads:
            background_tasks.add_task(
                analyze_pagespeed_batch,
                [l.id for l in valid_leads]
            )
        
        return {
            "message": f"Started PageSpeed analysis for {len(valid_leads)} leads",
            "total_requested": len(lead_ids),
            "valid_for_analysis": len(valid_leads),
            "skipped": len(lead_ids) - len(valid_leads)
        }
    
    def get_analysis_status(self) -> Dict[str, Any]:
        """Get PageSpeed analysis status across all leads."""
        total = self.db.query(Lead).count()
        
        with_scores = self.db.query(Lead).filter(
            Lead.pagespeed_mobile_score.isnot(None)
        ).count()
        
        without_website = self.db.query(Lead).filter(
            Lead.website_url.is_(None)
        ).count()
        
        return {
            "total_leads": total,
            "analyzed": with_scores,
            "pending": total - with_scores - without_website,
            "no_website": without_website,
            "completion_percentage": round((with_scores / total) * 100, 2) if total > 0 else 0
        }
    
    def get_missing_count(self) -> Dict[str, int]:
        """Get count of leads missing PageSpeed scores."""
        missing = self.db.query(Lead).filter(
            and_(
                Lead.website_url.isnot(None),
                Lead.pagespeed_mobile_score.is_(None)
            )
        ).count()
        
        return {"missing_pagespeed": missing}
    
    def process_missing_scores(
        self,
        background_tasks: BackgroundTasks,
        limit: int = 50
    ) -> Dict[str, Any]:
        """Process leads missing PageSpeed scores."""
        missing_leads = self.db.query(Lead).filter(
            and_(
                Lead.website_url.isnot(None),
                Lead.pagespeed_mobile_score.is_(None)
            )
        ).limit(limit).all()
        
        if missing_leads:
            lead_ids = [l.id for l in missing_leads]
            background_tasks.add_task(analyze_pagespeed_batch, lead_ids)
            
            return {
                "message": f"Started processing {len(lead_ids)} leads",
                "lead_ids": lead_ids
            }
        
        return {"message": "No leads to process"}