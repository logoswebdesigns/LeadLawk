"""
Admin user initialization service.
Pattern: Initialization Service Pattern - creates default admin on startup.
Single Responsibility: Default admin user creation only.
File size: <100 lines as per CLAUDE.md requirements.
"""

import logging
from sqlalchemy.orm import Session
from models import User
from .password_utils import hash_password
from .config import DEFAULT_ADMIN_EMAIL, DEFAULT_ADMIN_PASSWORD, DEFAULT_ADMIN_NAME

logger = logging.getLogger(__name__)


def create_default_admin(db: Session) -> None:
    """
    Create default admin user if no admin exists.
    
    Args:
        db: Database session
    """
    try:
        # Check if any admin user exists
        existing_admin = db.query(User).filter(User.is_admin == True).first()
        
        if existing_admin:
            logger.info("Admin user already exists, skipping creation")
            return
        
        # Check if default admin email already exists as regular user
        existing_user = db.query(User).filter(User.email == DEFAULT_ADMIN_EMAIL).first()
        
        if existing_user:
            # Promote existing user to admin
            existing_user.is_admin = True
            db.commit()
            logger.info(f"Promoted existing user {DEFAULT_ADMIN_EMAIL} to admin")
            return
        
        # Create new admin user
        hashed_password = hash_password(DEFAULT_ADMIN_PASSWORD)
        admin_user = User(
            email=DEFAULT_ADMIN_EMAIL,
            hashed_password=hashed_password,
            full_name=DEFAULT_ADMIN_NAME,
            is_admin=True,
            is_active=True
        )
        
        db.add(admin_user)
        db.commit()
        
        logger.info(f"Created default admin user: {DEFAULT_ADMIN_EMAIL}")
        logger.warning(f"Default admin password is: {DEFAULT_ADMIN_PASSWORD}")
        logger.warning("Please change the default admin password immediately!")
        
    except Exception as e:
        logger.error(f"Failed to create default admin user: {e}")
        db.rollback()
        raise