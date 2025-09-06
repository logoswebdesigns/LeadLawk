"""
Admin service for administrative operations.
Pattern: Service Layer Pattern - encapsulates admin logic.
Single Responsibility: Administrative operations only.
"""

from typing import Dict, Any
from sqlalchemy.orm import Session
from sqlalchemy import func
import os
import subprocess
import psutil
from datetime import datetime

from ..models import Lead, LeadStatus
from ..database import engine

class AdminService:
    """
    Service class for administrative operations.
    Pattern: Service Pattern with monitoring capabilities.
    """
    
    def __init__(self, db: Session):
        self.db = db
    
    def delete_all_leads(self) -> int:
        """Delete all leads from the database."""
        count = self.db.query(Lead).count()
        self.db.query(Lead).delete()
        self.db.commit()
        return count
    
    def delete_mock_leads(self) -> int:
        """Delete mock/test leads identified by specific patterns."""
        mock_query = self.db.query(Lead).filter(
            Lead.business_name.like('%MOCK%') |
            Lead.business_name.like('%TEST%') |
            Lead.business_name.like('%DEMO%')
        )
        count = mock_query.count()
        mock_query.delete(synchronize_session=False)
        self.db.commit()
        return count
    
    def cleanup_containers(self) -> Dict[str, str]:
        """Clean up Docker containers and resources."""
        try:
            if os.environ.get('USE_DOCKER') == '1':
                subprocess.run(['docker', 'system', 'prune', '-f'], check=True)
                return {"message": "Docker cleanup completed"}
            return {"message": "Not running in Docker environment"}
        except Exception as e:
            return {"error": str(e)}
    
    def get_diagnostics(self) -> Dict[str, Any]:
        """Get system diagnostics and health information."""
        stats = self.db.query(
            Lead.status,
            func.count(Lead.id).label('count')
        ).group_by(Lead.status).all()
        
        return {
            "timestamp": datetime.utcnow().isoformat(),
            "database": {
                "total_leads": sum(s.count for s in stats),
                "by_status": {s.status: s.count for s in stats},
                "connection": "active"
            },
            "system": {
                "cpu_percent": psutil.cpu_percent(),
                "memory_percent": psutil.virtual_memory().percent,
                "disk_usage": psutil.disk_usage('/').percent
            },
            "environment": {
                "docker": os.environ.get('USE_DOCKER') == '1',
                "selenium_hub": os.environ.get('SELENIUM_HUB_URL', 'not configured')
            }
        }