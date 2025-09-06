"""
Analytics service for data analysis.
Pattern: Service Layer Pattern - encapsulates analytics logic.
Single Responsibility: Data analysis and insights only.
"""

from typing import Dict, Any, List
from sqlalchemy.orm import Session
from sqlalchemy import func, and_
from datetime import datetime, timedelta

from ..models import Lead, LeadStatus
from ..analytics_engine import AnalyticsEngine


class AnalyticsService:
    """
    Service class for analytics operations.
    Pattern: Strategy Pattern for different analysis types.
    """
    
    def __init__(self, db: Session):
        self.db = db
        self.engine = AnalyticsEngine(db)
    
    def get_overview(self) -> Dict[str, Any]:
        """Get analytics overview with key metrics."""
        return self.engine.get_overview()
    
    def get_segments(self) -> Dict[str, Any]:
        """Get segmented analytics by various dimensions."""
        return self.engine.get_segments()
    
    def get_timeline(self) -> Dict[str, Any]:
        """Get timeline analytics for trend analysis."""
        return self.engine.get_timeline()
    
    def get_insights(self) -> Dict[str, Any]:
        """Generate AI-powered insights from data patterns."""
        overview = self.get_overview()
        segments = self.get_segments()
        
        insights = []
        
        if overview.get("conversion_rate", 0) < 0.1:
            insights.append({
                "type": "warning",
                "message": "Low conversion rate detected",
                "recommendation": "Focus on lead qualification"
            })
        
        top_location = max(
            segments.get("by_location", {}).items(),
            key=lambda x: x[1],
            default=(None, 0)
        )
        if top_location[0]:
            insights.append({
                "type": "opportunity",
                "message": f"High concentration in {top_location[0]}",
                "recommendation": f"Expand marketing in {top_location[0]}"
            })
        
        return {
            "insights": insights,
            "generated_at": datetime.utcnow().isoformat()
        }