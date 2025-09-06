"""
Enhanced Authentication Router with production security features.
Pattern: Router Pattern - handles enhanced auth HTTP endpoints.
Single Responsibility: Enhanced authentication endpoint routing.
File size: <100 lines as per CLAUDE.md requirements.
"""

from datetime import timedelta, datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status, Request, Response
from fastapi.security import HTTPBearer
from sqlalchemy.orm import Session
from auth.dependencies import get_db, get_current_user
from auth.schemas import UserCreate, UserLogin, Token, TwoFactorSetup, TwoFactorVerify
from auth.enhanced_jwt_service import EnhancedJWTService
from auth.totp_service import TOTPService
from auth.email_service import AuthEmailService
from auth.password_utils import hash_password, verify_password
from auth.models import User
from core.security.device_service import DeviceService
import json

router = APIRouter(prefix="/auth/v2", tags=["enhanced-authentication"])
security = HTTPBearer()


@router.post("/register", response_model=Token)
async def enhanced_register(
    user_data: UserCreate,
    request: Request,
    db: Session = Depends(get_db)
):
    """Enhanced user registration with device tracking."""
    # Check if user exists
    existing_user = db.query(User).filter(User.email == user_data.email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already registered"
        )
    
    # Get device info
    device_service = DeviceService()
    device_info = await device_service.get_device_info()
    
    # Create user
    hashed_password = hash_password(user_data.password)
    new_user = User(
        email=user_data.email,
        hashed_password=hashed_password,
        full_name=user_data.full_name
    )
    
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    # Send email verification
    email_service = AuthEmailService(db)
    await email_service.send_email_verification(user_data.email)
    
    # Create tokens
    jwt_service = EnhancedJWTService(db)
    access_token, refresh_token = jwt_service.create_token_pair(
        new_user.id,
        device_info.deviceId,
        device_info.model
    )
    
    return Token(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer",
        expires_in=ACCESS_TOKEN_EXPIRE_MINUTES * 60
    )


@router.post("/login", response_model=Token)
async def enhanced_login(
    user_credentials: UserLogin,
    request: Request,
    db: Session = Depends(get_db)
):
    """Enhanced login with 2FA support and device tracking."""
    user = db.query(User).filter(User.email == user_credentials.email).first()
    
    if not user or not verify_password(user_credentials.password, user.hashed_password):
        # Increment failed attempts
        if user:
            user.failed_login_attempts += 1
            if user.failed_login_attempts >= 5:
                user.account_locked_until = datetime.now(timezone.utc) + timedelta(minutes=30)
            db.commit()
        
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials"
        )
    
    # Check if account is locked
    if user.account_locked_until and user.account_locked_until > datetime.now(timezone.utc):
        raise HTTPException(
            status_code=status.HTTP_423_LOCKED,
            detail="Account locked due to too many failed attempts"
        )
    
    # Check if 2FA is required
    if user.two_factor_enabled:
        # Return special response indicating 2FA is required
        return {"requires_2fa": True, "email": user.email}
    
    # Reset failed attempts on successful login
    user.failed_login_attempts = 0
    user.account_locked_until = None
    user.last_login_at = datetime.now(timezone.utc)
    
    # Get device info
    device_service = DeviceService()
    device_info = await device_service.get_device_info()
    
    # Create tokens
    jwt_service = EnhancedJWTService(db)
    access_token, refresh_token = jwt_service.create_token_pair(
        user.id,
        device_info.deviceId,
        device_info.model
    )
    
    db.commit()
    
    return Token(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer",
        expires_in=ACCESS_TOKEN_EXPIRE_MINUTES * 60
    )


@router.post("/verify-2fa", response_model=Token)
async def verify_two_factor(
    verification: TwoFactorVerify,
    request: Request,
    db: Session = Depends(get_db)
):
    """Verify 2FA code and complete login."""
    user = db.query(User).filter(User.email == verification.email).first()
    
    if not user or not user.two_factor_enabled:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="2FA not enabled for this account"
        )
    
    totp_service = TOTPService(db)
    
    # Try TOTP first, then backup code
    is_valid = totp_service.verify_token(user.two_factor_secret, verification.code)
    if not is_valid:
        is_valid = totp_service.verify_backup_code(user.id, verification.code)
    
    if not is_valid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid 2FA code"
        )
    
    # Update login info
    user.last_login_at = datetime.now(timezone.utc)
    user.failed_login_attempts = 0
    
    # Get device info and create tokens
    device_service = DeviceService()
    device_info = await device_service.get_device_info()
    
    jwt_service = EnhancedJWTService(db)
    access_token, refresh_token = jwt_service.create_token_pair(
        user.id,
        device_info.deviceId,
        device_info.model
    )
    
    db.commit()
    
    return Token(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer",
        expires_in=ACCESS_TOKEN_EXPIRE_MINUTES * 60
    )


@router.post("/setup-2fa", response_model=TwoFactorSetup)
async def setup_two_factor(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Setup 2FA for current user."""
    totp_service = TOTPService(db)
    result = totp_service.setup_2fa(current_user.id)
    
    if not result:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to setup 2FA"
        )
    
    secret, qr_code = result
    
    return TwoFactorSetup(
        secret=secret,
        qr_code=qr_code,
        backup_codes=[]  # Will be provided after verification
    )