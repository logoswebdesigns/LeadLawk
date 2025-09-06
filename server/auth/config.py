"""
Authentication configuration.
Pattern: Configuration Object Pattern - centralized auth settings.
Single Responsibility: Manages authentication configuration only.
File size: <100 lines as per CLAUDE.md requirements.
"""

import os
from datetime import timedelta

# JWT Configuration
SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-change-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "30"))
REFRESH_TOKEN_EXPIRE_DAYS = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "7"))

# Rate Limiting Configuration
DEFAULT_RATE_LIMIT = int(os.getenv("DEFAULT_RATE_LIMIT", "100"))  # requests per minute
ADMIN_RATE_LIMIT = int(os.getenv("ADMIN_RATE_LIMIT", "1000"))    # requests per minute

# Password Configuration
PASSWORD_MIN_LENGTH = 8
PASSWORD_REQUIRE_SPECIAL_CHARS = True

# Token scopes
SCOPES = {
    "read": "Read access to resources",
    "write": "Write access to resources", 
    "admin": "Administrative access"
}

# Default admin user (created on first startup if not exists)
DEFAULT_ADMIN_EMAIL = os.getenv("DEFAULT_ADMIN_EMAIL", "admin@leadlawk.com")
DEFAULT_ADMIN_PASSWORD = os.getenv("DEFAULT_ADMIN_PASSWORD", "changeMe123!")
DEFAULT_ADMIN_NAME = "System Administrator"