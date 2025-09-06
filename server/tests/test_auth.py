"""
Unit tests for authentication system.
Pattern: Test Pattern - comprehensive auth testing.
Single Responsibility: Authentication testing only.
File size: <100 lines as per CLAUDE.md requirements.
"""

import pytest
from datetime import datetime, timezone, timedelta
from auth.password_utils import hash_password, verify_password, validate_password_strength
from auth.jwt_service import create_access_token, verify_token
from auth.config import SECRET_KEY, ALGORITHM


class TestPasswordUtils:
    """Test password utilities."""
    
    def test_hash_password(self):
        """Test password hashing."""
        password = "test_password123"
        hashed = hash_password(password)
        assert hashed != password
        assert len(hashed) > 0
        
    def test_verify_password_correct(self):
        """Test password verification with correct password."""
        password = "test_password123"
        hashed = hash_password(password)
        assert verify_password(password, hashed) is True
        
    def test_verify_password_incorrect(self):
        """Test password verification with incorrect password."""
        password = "test_password123"
        wrong_password = "wrong_password"
        hashed = hash_password(password)
        assert verify_password(wrong_password, hashed) is False
        
    def test_validate_password_strength_valid(self):
        """Test password strength validation with valid password."""
        valid_password = "StrongP@ss123"
        result = validate_password_strength(valid_password)
        assert result is None
        
    def test_validate_password_strength_weak(self):
        """Test password strength validation with weak password."""
        weak_password = "weak"
        result = validate_password_strength(weak_password)
        assert result is not None
        assert "8 characters" in result


class TestJWTService:
    """Test JWT service."""
    
    def test_create_and_verify_token(self):
        """Test token creation and verification."""
        data = {"sub": "user123", "email": "test@example.com"}
        token = create_access_token(data)
        assert token is not None
        assert len(token) > 0
        
        payload = verify_token(token)
        assert payload is not None
        assert payload["sub"] == "user123"
        assert payload["email"] == "test@example.com"
        
    def test_verify_invalid_token(self):
        """Test verification of invalid token."""
        invalid_token = "invalid.token.here"
        payload = verify_token(invalid_token)
        assert payload is None
        
    def test_token_expiration(self):
        """Test token expiration."""
        data = {"sub": "user123"}
        # Create token with very short expiration
        expired_delta = timedelta(microseconds=1)
        token = create_access_token(data, expires_delta=expired_delta)
        
        # Wait a bit and verify token is expired
        import time
        time.sleep(0.001)
        
        payload = verify_token(token)
        # Token should be expired and verification should fail
        assert payload is None


if __name__ == "__main__":
    pytest.main([__file__])