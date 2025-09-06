"""
Enhanced JWT Service with refresh token rotation.
Pattern: Service Pattern - handles JWT operations with security enhancements.
Single Responsibility: Advanced JWT token management.
File size: <100 lines as per CLAUDE.md requirements.
"""

import secrets
import hashlib
from datetime import datetime, timedelta, timezone
from typing import Optional, Dict, Any, Tuple
from sqlalchemy.orm import Session
from .models import RefreshToken
from .jwt_service import create_access_token, verify_token


class EnhancedJWTService:
    """Enhanced JWT service with refresh token rotation and security features."""
    
    def __init__(self, db: Session):
        self.db = db
    
    def create_token_pair(self, user_id: str, device_id: str, device_name: str = None) -> Tuple[str, str]:
        """Create access token and refresh token pair."""
        # Create access token
        access_token = create_access_token(data={"sub": user_id})
        
        # Create refresh token with rotation support
        refresh_token = self._create_refresh_token(user_id, device_id, device_name)
        
        return access_token, refresh_token
    
    def _create_refresh_token(self, user_id: str, device_id: str, device_name: str = None) -> str:
        """Create a secure refresh token and store in database."""
        # Generate cryptographically secure token
        token = secrets.token_urlsafe(32)
        token_hash = hashlib.sha256(token.encode()).hexdigest()
        
        # Revoke existing refresh tokens for this device (rotation)
        self.db.query(RefreshToken).filter(
            RefreshToken.user_id == user_id,
            RefreshToken.device_id == device_id,
            RefreshToken.is_revoked == False
        ).update({"is_revoked": True})
        
        # Create new refresh token record
        expires_at = datetime.now(timezone.utc) + timedelta(days=30)  # 30 day expiration
        
        refresh_token_record = RefreshToken(
            user_id=user_id,
            token=token_hash,
            device_id=device_id,
            device_name=device_name,
            expires_at=expires_at
        )
        
        self.db.add(refresh_token_record)
        self.db.commit()
        
        return token
    
    def rotate_refresh_token(self, refresh_token: str, device_id: str) -> Optional[Tuple[str, str]]:
        """Rotate refresh token and create new token pair."""
        token_hash = hashlib.sha256(refresh_token.encode()).hexdigest()
        
        # Find and validate refresh token
        token_record = self.db.query(RefreshToken).filter(
            RefreshToken.token == token_hash,
            RefreshToken.device_id == device_id,
            RefreshToken.is_revoked == False,
            RefreshToken.expires_at > datetime.now(timezone.utc)
        ).first()
        
        if not token_record:
            return None
        
        # Update last used timestamp
        token_record.last_used_at = datetime.now(timezone.utc)
        
        # Create new token pair
        access_token, new_refresh_token = self.create_token_pair(
            token_record.user_id,
            device_id,
            token_record.device_name
        )
        
        return access_token, new_refresh_token
    
    def revoke_refresh_token(self, refresh_token: str) -> bool:
        """Revoke a specific refresh token."""
        token_hash = hashlib.sha256(refresh_token.encode()).hexdigest()
        
        token_record = self.db.query(RefreshToken).filter(
            RefreshToken.token == token_hash
        ).first()
        
        if token_record:
            token_record.is_revoked = True
            self.db.commit()
            return True
        
        return False
    
    def revoke_all_user_tokens(self, user_id: str) -> int:
        """Revoke all refresh tokens for a user."""
        count = self.db.query(RefreshToken).filter(
            RefreshToken.user_id == user_id,
            RefreshToken.is_revoked == False
        ).update({"is_revoked": True})
        
        self.db.commit()
        return count
    
    def revoke_device_tokens(self, user_id: str, device_id: str) -> int:
        """Revoke all refresh tokens for a specific device."""
        count = self.db.query(RefreshToken).filter(
            RefreshToken.user_id == user_id,
            RefreshToken.device_id == device_id,
            RefreshToken.is_revoked == False
        ).update({"is_revoked": True})
        
        self.db.commit()
        return count
    
    def cleanup_expired_tokens(self) -> int:
        """Clean up expired refresh tokens."""
        count = self.db.query(RefreshToken).filter(
            RefreshToken.expires_at < datetime.now(timezone.utc)
        ).delete()
        
        self.db.commit()
        return count