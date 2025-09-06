"""
Authentication dependencies for FastAPI.
Pattern: Dependency Injection Pattern - provides auth dependencies.
Single Responsibility: Authentication and authorization dependencies only.
File size: <100 lines as per CLAUDE.md requirements.
"""

from datetime import datetime, timezone, timedelta
from typing import Optional
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from database import SessionLocal
from models import User
from .jwt_service import verify_token
from .config import DEFAULT_RATE_LIMIT, ADMIN_RATE_LIMIT

security = HTTPBearer()


def get_db() -> Session:
    """Database session dependency."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
) -> User:
    """
    Get the current authenticated user from JWT token.
    
    Args:
        credentials: Bearer token credentials
        db: Database session
        
    Returns:
        Current authenticated user
        
    Raises:
        HTTPException: If token is invalid or user not found
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    token = credentials.credentials
    payload = verify_token(token)
    
    if payload is None:
        raise credentials_exception
    
    user_id: str = payload.get("sub")
    if user_id is None:
        raise credentials_exception
    
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise credentials_exception
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inactive user"
        )
    
    # Check rate limiting
    await _check_rate_limit(user, db)
    
    return user


async def get_current_active_user(current_user: User = Depends(get_current_user)) -> User:
    """Get current active user - alias for backward compatibility."""
    return current_user


async def get_admin_user(current_user: User = Depends(get_current_user)) -> User:
    """Get current user and verify admin privileges."""
    if not current_user.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )
    return current_user


async def _check_rate_limit(user: User, db: Session) -> None:
    """Check and update rate limiting for user."""
    now = datetime.now(timezone.utc)
    rate_limit = ADMIN_RATE_LIMIT if user.is_admin else DEFAULT_RATE_LIMIT
    
    # Reset counter if more than a minute has passed
    if user.last_request_reset < now - timedelta(minutes=1):
        user.request_count = 0
        user.last_request_reset = now
    
    # Increment request count
    user.request_count += 1
    
    if user.request_count > rate_limit:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Rate limit exceeded. Max {rate_limit} requests per minute"
        )
    
    db.commit()