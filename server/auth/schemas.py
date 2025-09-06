"""
Authentication Pydantic schemas.
Pattern: Data Transfer Object Pattern - API request/response models.
Single Responsibility: Authentication data validation only.
File size: <100 lines as per CLAUDE.md requirements.
"""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, EmailStr, validator
from .password_utils import validate_password_strength


class UserCreate(BaseModel):
    """Schema for user creation."""
    email: EmailStr
    password: str
    full_name: str
    
    @validator('password')
    def validate_password(cls, v):
        error = validate_password_strength(v)
        if error:
            raise ValueError(error)
        return v


class UserLogin(BaseModel):
    """Schema for user login."""
    email: EmailStr
    password: str


class UserResponse(BaseModel):
    """Schema for user response (without password)."""
    id: str
    email: str
    full_name: str
    is_active: bool
    is_admin: bool
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True


class UserUpdate(BaseModel):
    """Schema for user profile update."""
    full_name: Optional[str] = None
    email: Optional[EmailStr] = None


class Token(BaseModel):
    """Schema for JWT token response."""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int  # seconds


class TokenData(BaseModel):
    """Schema for token data validation."""
    user_id: Optional[str] = None


class RefreshTokenRequest(BaseModel):
    """Schema for refresh token request."""
    refresh_token: str


class PasswordChange(BaseModel):
    """Schema for password change request."""
    current_password: str
    new_password: str
    
    @validator('new_password')
    def validate_new_password(cls, v):
        error = validate_password_strength(v)
        if error:
            raise ValueError(error)
        return v