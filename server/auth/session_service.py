"""
Session Management Service.
Pattern: Service Pattern - handles user session tracking and management.
Single Responsibility: Session lifecycle management.
File size: <100 lines as per CLAUDE.md requirements.
"""

from datetime import datetime, timedelta, timezone
from typing import List, Optional
from sqlalchemy.orm import Session
from .models import UserSession, TrustedDevice, User
import geoip2.database
import user_agents


class SessionService:
    """Service for managing user sessions and device tracking."""
    
    def __init__(self, db: Session):
        self.db = db
    
    def create_session(
        self,
        user_id: str,
        device_id: str,
        device_name: str,
        platform: str,
        ip_address: str,
        user_agent: str
    ) -> UserSession:
        """Create a new user session."""
        # Parse user agent for device info
        parsed_agent = user_agents.parse(user_agent)
        device_info = f"{parsed_agent.browser.family} on {parsed_agent.os.family}"
        
        # Get location from IP (optional - requires GeoIP database)
        location = self._get_location_from_ip(ip_address)
        
        # Create session
        session = UserSession(
            user_id=user_id,
            device_id=device_id,
            device_name=device_name or device_info,
            platform=platform,
            ip_address=ip_address,
            location=location,
            user_agent=user_agent,
            expires_at=datetime.now(timezone.utc) + timedelta(days=30)
        )
        
        self.db.add(session)
        self.db.commit()
        self.db.refresh(session)
        
        return session
    
    def update_session_activity(self, session_id: str) -> bool:
        """Update last activity timestamp for a session."""
        session = self.db.query(UserSession).filter(
            UserSession.id == session_id,
            UserSession.is_active == True
        ).first()
        
        if session:
            session.last_active_at = datetime.now(timezone.utc)
            self.db.commit()
            return True
        
        return False
    
    def get_user_sessions(self, user_id: str) -> List[UserSession]:
        """Get all active sessions for a user."""
        return self.db.query(UserSession).filter(
            UserSession.user_id == user_id,
            UserSession.is_active == True,
            UserSession.expires_at > datetime.now(timezone.utc)
        ).order_by(UserSession.last_active_at.desc()).all()
    
    def revoke_session(self, user_id: str, session_id: str) -> bool:
        """Revoke a specific session for a user."""
        session = self.db.query(UserSession).filter(
            UserSession.id == session_id,
            UserSession.user_id == user_id
        ).first()
        
        if session:
            session.is_active = False
            self.db.commit()
            return True
        
        return False
    
    def revoke_all_sessions(self, user_id: str, except_session_id: str = None) -> int:
        """Revoke all sessions for a user except optionally one."""
        query = self.db.query(UserSession).filter(
            UserSession.user_id == user_id,
            UserSession.is_active == True
        )
        
        if except_session_id:
            query = query.filter(UserSession.id != except_session_id)
        
        count = query.update({"is_active": False})
        self.db.commit()
        
        return count
    
    def trust_device(self, user_id: str, device_id: str, device_name: str, platform: str) -> TrustedDevice:
        """Mark a device as trusted for a user."""
        # Check if device is already trusted
        existing = self.db.query(TrustedDevice).filter(
            TrustedDevice.user_id == user_id,
            TrustedDevice.device_id == device_id
        ).first()
        
        if existing:
            existing.is_trusted = True
            existing.last_used_at = datetime.now(timezone.utc)
            self.db.commit()
            return existing
        
        # Create new trusted device
        trusted_device = TrustedDevice(
            user_id=user_id,
            device_id=device_id,
            device_name=device_name,
            platform=platform
        )
        
        self.db.add(trusted_device)
        self.db.commit()
        self.db.refresh(trusted_device)
        
        return trusted_device
    
    def untrust_device(self, user_id: str, device_id: str) -> bool:
        """Remove trust from a device."""
        trusted_device = self.db.query(TrustedDevice).filter(
            TrustedDevice.user_id == user_id,
            TrustedDevice.device_id == device_id
        ).first()
        
        if trusted_device:
            trusted_device.is_trusted = False
            self.db.commit()
            return True
        
        return False
    
    def is_device_trusted(self, user_id: str, device_id: str) -> bool:
        """Check if a device is trusted for a user."""
        trusted_device = self.db.query(TrustedDevice).filter(
            TrustedDevice.user_id == user_id,
            TrustedDevice.device_id == device_id,
            TrustedDevice.is_trusted == True
        ).first()
        
        return trusted_device is not None
    
    def cleanup_expired_sessions(self) -> int:
        """Clean up expired sessions."""
        count = self.db.query(UserSession).filter(
            UserSession.expires_at < datetime.now(timezone.utc)
        ).update({"is_active": False})
        
        self.db.commit()
        return count
    
    def _get_location_from_ip(self, ip_address: str) -> Optional[str]:
        """Get location from IP address using GeoIP."""
        try:
            # This requires GeoLite2 database file
            # with geoip2.database.Reader('/path/to/GeoLite2-City.mmdb') as reader:
            #     response = reader.city(ip_address)
            #     return f"{response.city.name}, {response.country.name}"
            
            # For now, return None - implement when you have GeoIP database
            return None
        except Exception:
            return None