"""Authentication models.
Pattern: Domain Model Pattern.
Single Responsibility: Define auth entities.
"""

from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, EmailStr, Field
from enum import Enum


class UserRole(str, Enum):
    """User roles for RBAC."""
    ADMIN = "admin"
    MANAGER = "manager"
    AGENT = "agent"
    VIEWER = "viewer"


class User(BaseModel):
    """User model."""
    id: str
    email: EmailStr
    username: str
    full_name: str
    role: UserRole
    is_active: bool = True
    created_at: datetime
    updated_at: datetime
    last_login: Optional[datetime] = None
    
    class Config:
        from_attributes = True


class UserCreate(BaseModel):
    """User creation model."""
    email: EmailStr
    username: str = Field(..., min_length=3, max_length=50)
    password: str = Field(..., min_length=8)
    full_name: str
    role: UserRole = UserRole.AGENT


class UserLogin(BaseModel):
    """User login model."""
    username: str
    password: str


class Token(BaseModel):
    """JWT token model."""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class TokenData(BaseModel):
    """Token payload data."""
    sub: str  # Subject (user_id)
    email: str
    role: UserRole
    exp: int  # Expiration
    iat: int  # Issued at
    jti: Optional[str] = None  # JWT ID for refresh tokens


class RefreshToken(BaseModel):
    """Refresh token model."""
    token: str
    user_id: str
    expires_at: datetime
    is_revoked: bool = False
    created_at: datetime