"""Authentication API endpoints.
Pattern: Controller Pattern.
Single Responsibility: Handle auth requests.
"""

from typing import Dict, Any
from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session
from datetime import datetime

from .models import UserCreate, UserLogin, Token, User, TokenData
from .jwt_service import JWTService
from .middleware import AuthBearer, require_admin
from .rate_limiter import strict_rate_limiter
from ..database import get_db


router = APIRouter(prefix="/auth", tags=["Authentication"])


# Mock user store (replace with database)
USERS_DB: Dict[str, Dict[str, Any]] = {
    "admin": {
        "id": "1",
        "username": "admin",
        "email": "admin@leadlawk.com",
        "full_name": "Admin User",
        "hashed_password": JWTService.hash_password("admin123"),
        "role": "admin",
        "is_active": True,
        "created_at": datetime.utcnow(),
        "updated_at": datetime.utcnow()
    }
}

# Refresh token store (replace with database)
REFRESH_TOKENS: Dict[str, Dict[str, Any]] = {}


@router.post("/register", response_model=User)
async def register(
    user_data: UserCreate,
    _: TokenData = Depends(require_admin)
):
    """Register a new user (admin only)."""
    # Check if user exists
    if user_data.username in USERS_DB:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already registered"
        )
    
    # Create user
    user_id = str(len(USERS_DB) + 1)
    user = {
        "id": user_id,
        "username": user_data.username,
        "email": user_data.email,
        "full_name": user_data.full_name,
        "hashed_password": JWTService.hash_password(user_data.password),
        "role": user_data.role.value,
        "is_active": True,
        "created_at": datetime.utcnow(),
        "updated_at": datetime.utcnow()
    }
    
    USERS_DB[user_data.username] = user
    
    return User(**user)


@router.post("/login", response_model=Token, dependencies=[Depends(strict_rate_limiter)])
async def login(credentials: UserLogin):
    """Login with username and password."""
    # Get user
    user = USERS_DB.get(credentials.username)
    
    if not user or not JWTService.verify_password(
        credentials.password,
        user["hashed_password"]
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password"
        )
    
    if not user["is_active"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is disabled"
        )
    
    # Create tokens
    access_token = JWTService.create_access_token(
        user_id=user["id"],
        email=user["email"],
        role=user["role"]
    )
    
    refresh_token, jti = JWTService.create_refresh_token(user_id=user["id"])
    
    # Store refresh token
    REFRESH_TOKENS[jti] = {
        "user_id": user["id"],
        "created_at": datetime.utcnow()
    }
    
    # Update last login
    user["last_login"] = datetime.utcnow()
    
    return Token(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=JWTService.ACCESS_TOKEN_EXPIRE_MINUTES * 60
    )


@router.post("/refresh", response_model=Token)
async def refresh_token(refresh_token: str):
    """Refresh access token using refresh token."""
    # Verify refresh token
    payload = JWTService.verify_refresh_token(refresh_token)
    
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token"
        )
    
    # Check if token is revoked
    jti = payload.get("jti")
    if jti not in REFRESH_TOKENS:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token has been revoked"
        )
    
    # Get user
    user_id = payload["sub"]
    user = next(
        (u for u in USERS_DB.values() if u["id"] == user_id),
        None
    )
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Create new access token
    access_token = JWTService.create_access_token(
        user_id=user["id"],
        email=user["email"],
        role=user["role"]
    )
    
    return Token(
        access_token=access_token,
        refresh_token=refresh_token,  # Return same refresh token
        expires_in=JWTService.ACCESS_TOKEN_EXPIRE_MINUTES * 60
    )


@router.post("/logout")
async def logout(
    token_data: TokenData = Depends(AuthBearer())
):
    """Logout and revoke tokens."""
    # In production, add token to blacklist
    return {"message": "Successfully logged out"}


@router.get("/me", response_model=User)
async def get_current_user(
    token_data: TokenData = Depends(AuthBearer())
):
    """Get current user info."""
    user = next(
        (u for u in USERS_DB.values() if u["id"] == token_data.sub),
        None
    )
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    return User(**user)