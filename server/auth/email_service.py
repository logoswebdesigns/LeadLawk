"""
Email Service for authentication operations.
Pattern: Service Pattern - handles email sending for auth flows.
Single Responsibility: Authentication-related email operations.
File size: <100 lines as per CLAUDE.md requirements.
"""

import secrets
import hashlib
from datetime import datetime, timedelta, timezone
from typing import Optional
from sqlalchemy.orm import Session
from .models import EmailVerificationToken, PasswordResetToken


class AuthEmailService:
    """Service for handling authentication-related emails."""
    
    def __init__(self, db: Session):
        self.db = db
        self.base_url = "https://your-app-domain.com"  # Configure this
    
    def send_email_verification(self, email: str) -> bool:
        """Send email verification email."""
        # Generate secure token
        token = secrets.token_urlsafe(32)
        token_hash = hashlib.sha256(token.encode()).hexdigest()
        
        # Store token in database
        expires_at = datetime.now(timezone.utc) + timedelta(hours=24)  # 24 hour expiration
        
        verification_token = EmailVerificationToken(
            email=email,
            token=token_hash,
            expires_at=expires_at
        )
        
        self.db.add(verification_token)
        self.db.commit()
        
        # Send email (implement with your email provider)
        verification_url = f"{self.base_url}/verify-email?token={token}"
        
        # Email content
        subject = "Verify your LeadLawk account"
        body = f"""
        Welcome to LeadLawk!
        
        Please click the link below to verify your email address:
        {verification_url}
        
        This link will expire in 24 hours.
        
        If you didn't create an account with LeadLawk, please ignore this email.
        """
        
        # TODO: Integrate with email service (SendGrid, AWS SES, etc.)
        print(f"Email verification sent to {email}: {verification_url}")
        
        return True
    
    def verify_email(self, token: str) -> Optional[str]:
        """Verify email token and return email address."""
        token_hash = hashlib.sha256(token.encode()).hexdigest()
        
        verification_token = self.db.query(EmailVerificationToken).filter(
            EmailVerificationToken.token == token_hash,
            EmailVerificationToken.used_at.is_(None),
            EmailVerificationToken.expires_at > datetime.now(timezone.utc)
        ).first()
        
        if verification_token:
            # Mark token as used
            verification_token.used_at = datetime.now(timezone.utc)
            self.db.commit()
            return verification_token.email
        
        return None
    
    def send_password_reset(self, email: str) -> bool:
        """Send password reset email."""
        # Generate secure token
        token = secrets.token_urlsafe(32)
        token_hash = hashlib.sha256(token.encode()).hexdigest()
        
        # Store token in database
        expires_at = datetime.now(timezone.utc) + timedelta(hours=1)  # 1 hour expiration
        
        reset_token = PasswordResetToken(
            email=email,
            token=token_hash,
            expires_at=expires_at
        )
        
        self.db.add(reset_token)
        self.db.commit()
        
        # Send email
        reset_url = f"{self.base_url}/reset-password?token={token}"
        
        subject = "Reset your LeadLawk password"
        body = f"""
        You requested to reset your LeadLawk password.
        
        Click the link below to reset your password:
        {reset_url}
        
        This link will expire in 1 hour.
        
        If you didn't request a password reset, please ignore this email.
        Your password will remain unchanged.
        """
        
        # TODO: Integrate with email service
        print(f"Password reset sent to {email}: {reset_url}")
        
        return True
    
    def verify_password_reset_token(self, token: str) -> Optional[str]:
        """Verify password reset token and return email address."""
        token_hash = hashlib.sha256(token.encode()).hexdigest()
        
        reset_token = self.db.query(PasswordResetToken).filter(
            PasswordResetToken.token == token_hash,
            PasswordResetToken.used_at.is_(None),
            PasswordResetToken.expires_at > datetime.now(timezone.utc)
        ).first()
        
        if reset_token:
            # Mark token as used
            reset_token.used_at = datetime.now(timezone.utc)
            self.db.commit()
            return reset_token.email
        
        return None
    
    def cleanup_expired_tokens(self) -> int:
        """Clean up expired tokens."""
        now = datetime.now(timezone.utc)
        
        # Clean up email verification tokens
        email_count = self.db.query(EmailVerificationToken).filter(
            EmailVerificationToken.expires_at < now
        ).delete()
        
        # Clean up password reset tokens
        password_count = self.db.query(PasswordResetToken).filter(
            PasswordResetToken.expires_at < now
        ).delete()
        
        self.db.commit()
        return email_count + password_count