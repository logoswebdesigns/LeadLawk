"""
TOTP (Time-based One-Time Password) Service for 2FA.
Pattern: Service Pattern - handles TOTP generation and verification.
Single Responsibility: Two-factor authentication operations.
File size: <100 lines as per CLAUDE.md requirements.
"""

import pyotp
import qrcode
import secrets
import hashlib
import json
from io import BytesIO
from typing import List, Optional, Tuple
from sqlalchemy.orm import Session
from .models import User


class TOTPService:
    """Service for handling TOTP-based two-factor authentication."""
    
    def __init__(self, db: Session):
        self.db = db
        self.issuer_name = "LeadLawk"
    
    def generate_secret(self) -> str:
        """Generate a new TOTP secret."""
        return pyotp.random_base32()
    
    def generate_qr_code(self, user_email: str, secret: str) -> bytes:
        """Generate QR code for TOTP setup."""
        totp_uri = pyotp.totp.TOTP(secret).provisioning_uri(
            name=user_email,
            issuer_name=self.issuer_name
        )
        
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_L,
            box_size=10,
            border=4,
        )
        qr.add_data(totp_uri)
        qr.make(fit=True)
        
        img = qr.make_image(fill_color="black", back_color="white")
        img_buffer = BytesIO()
        img.save(img_buffer, format='PNG')
        return img_buffer.getvalue()
    
    def verify_token(self, secret: str, token: str, window: int = 1) -> bool:
        """Verify a TOTP token."""
        totp = pyotp.TOTP(secret)
        return totp.verify(token, valid_window=window)
    
    def enable_2fa(self, user_id: str, verification_token: str) -> Optional[List[str]]:
        """Enable 2FA for a user after token verification."""
        user = self.db.query(User).filter(User.id == user_id).first()
        if not user or not user.two_factor_secret:
            return None
        
        # Verify the token before enabling
        if not self.verify_token(user.two_factor_secret, verification_token):
            return None
        
        # Generate backup codes
        backup_codes = self.generate_backup_codes()
        
        # Enable 2FA and store backup codes
        user.two_factor_enabled = True
        user.backup_codes = json.dumps([self._hash_backup_code(code) for code in backup_codes])
        
        self.db.commit()
        return backup_codes
    
    def disable_2fa(self, user_id: str) -> bool:
        """Disable 2FA for a user."""
        user = self.db.query(User).filter(User.id == user_id).first()
        if not user:
            return False
        
        user.two_factor_enabled = False
        user.two_factor_secret = None
        user.backup_codes = None
        
        self.db.commit()
        return True
    
    def setup_2fa(self, user_id: str) -> Optional[Tuple[str, bytes]]:
        """Setup 2FA for a user - generate secret and QR code."""
        user = self.db.query(User).filter(User.id == user_id).first()
        if not user:
            return None
        
        # Generate new secret
        secret = self.generate_secret()
        user.two_factor_secret = secret
        
        # Generate QR code
        qr_code = self.generate_qr_code(user.email, secret)
        
        self.db.commit()
        return secret, qr_code
    
    def generate_backup_codes(self, count: int = 10) -> List[str]:
        """Generate backup codes for 2FA recovery."""
        codes = []
        for _ in range(count):
            # Generate 8-digit backup code
            code = secrets.randbelow(100000000)
            codes.append(f"{code:08d}")
        return codes
    
    def verify_backup_code(self, user_id: str, backup_code: str) -> bool:
        """Verify a backup code and invalidate it."""
        user = self.db.query(User).filter(User.id == user_id).first()
        if not user or not user.backup_codes:
            return False
        
        backup_codes = json.loads(user.backup_codes)
        code_hash = self._hash_backup_code(backup_code)
        
        if code_hash in backup_codes:
            # Remove the used backup code
            backup_codes.remove(code_hash)
            user.backup_codes = json.dumps(backup_codes)
            self.db.commit()
            return True
        
        return False
    
    def regenerate_backup_codes(self, user_id: str) -> Optional[List[str]]:
        """Regenerate backup codes for a user."""
        user = self.db.query(User).filter(User.id == user_id).first()
        if not user or not user.two_factor_enabled:
            return None
        
        backup_codes = self.generate_backup_codes()
        user.backup_codes = json.dumps([self._hash_backup_code(code) for code in backup_codes])
        
        self.db.commit()
        return backup_codes
    
    def _hash_backup_code(self, code: str) -> str:
        """Hash a backup code for secure storage."""
        return hashlib.sha256(code.encode()).hexdigest()