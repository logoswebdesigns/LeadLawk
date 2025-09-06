"""JWT token service.
Pattern: Service Pattern.
Single Responsibility: Manage JWT tokens.
"""

from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from jose import jwt, JWTError
from passlib.context import CryptContext
import secrets
import os

from .models import TokenData, UserRole


class JWTService:
    """JWT token management service."""
    
    # Configuration
    SECRET_KEY = os.getenv("JWT_SECRET_KEY", secrets.token_urlsafe(32))
    REFRESH_SECRET_KEY = os.getenv("JWT_REFRESH_SECRET", secrets.token_urlsafe(32))
    ALGORITHM = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES = 30
    REFRESH_TOKEN_EXPIRE_DAYS = 7
    
    # Password hashing
    pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
    
    @classmethod
    def create_access_token(
        cls,
        user_id: str,
        email: str,
        role: UserRole,
        expires_delta: Optional[timedelta] = None
    ) -> str:
        """Create JWT access token."""
        now = datetime.utcnow()
        expire = now + (expires_delta or timedelta(minutes=cls.ACCESS_TOKEN_EXPIRE_MINUTES))
        
        payload = {
            "sub": user_id,
            "email": email,
            "role": role.value,
            "exp": expire,
            "iat": now,
            "type": "access"
        }
        
        return jwt.encode(payload, cls.SECRET_KEY, algorithm=cls.ALGORITHM)
    
    @classmethod
    def create_refresh_token(
        cls,
        user_id: str,
        expires_delta: Optional[timedelta] = None
    ) -> tuple[str, str]:
        """Create JWT refresh token. Returns (token, jti)."""
        now = datetime.utcnow()
        expire = now + (expires_delta or timedelta(days=cls.REFRESH_TOKEN_EXPIRE_DAYS))
        jti = secrets.token_urlsafe(32)
        
        payload = {
            "sub": user_id,
            "exp": expire,
            "iat": now,
            "jti": jti,
            "type": "refresh"
        }
        
        token = jwt.encode(payload, cls.REFRESH_SECRET_KEY, algorithm=cls.ALGORITHM)
        return token, jti
    
    @classmethod
    def verify_access_token(cls, token: str) -> Optional[TokenData]:
        """Verify and decode access token."""
        try:
            payload = jwt.decode(token, cls.SECRET_KEY, algorithms=[cls.ALGORITHM])
            
            if payload.get("type") != "access":
                return None
            
            return TokenData(
                sub=payload["sub"],
                email=payload["email"],
                role=UserRole(payload["role"]),
                exp=payload["exp"],
                iat=payload["iat"]
            )
        except JWTError:
            return None
    
    @classmethod
    def verify_refresh_token(cls, token: str) -> Optional[Dict[str, Any]]:
        """Verify and decode refresh token."""
        try:
            payload = jwt.decode(token, cls.REFRESH_SECRET_KEY, algorithms=[cls.ALGORITHM])
            
            if payload.get("type") != "refresh":
                return None
            
            return payload
        except JWTError:
            return None
    
    @classmethod
    def hash_password(cls, password: str) -> str:
        """Hash a password."""
        return cls.pwd_context.hash(password)
    
    @classmethod
    def verify_password(cls, plain_password: str, hashed_password: str) -> bool:
        """Verify a password against hash."""
        return cls.pwd_context.verify(plain_password, hashed_password)