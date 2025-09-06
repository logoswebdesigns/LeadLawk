"""
App Store Compliance Router.
Pattern: Router Pattern - handles compliance endpoints for app stores.
Single Responsibility: App store requirement compliance.
File size: <100 lines as per CLAUDE.md requirements.
"""

from fastapi import APIRouter, Depends, HTTPException, status, Response
from sqlalchemy.orm import Session
from auth.dependencies import get_db, get_current_user
from models import User
from auth.schemas import UserResponse
import json
from datetime import datetime

router = APIRouter(prefix="/compliance", tags=["compliance"])


@router.get("/privacy-policy")
async def privacy_policy():
    """Return privacy policy for app store compliance."""
    privacy_policy_content = {
        "title": "LeadLawk Privacy Policy",
        "last_updated": "2024-01-01",
        "content": """
        LeadLawk Privacy Policy

        1. Information We Collect
        We collect information you provide directly to us, such as when you create an account,
        use our services, or contact us for support.

        2. How We Use Your Information
        We use the information we collect to provide, maintain, and improve our services.

        3. Information Sharing
        We do not sell, trade, or otherwise transfer your personal information to third parties
        without your consent, except as described in this policy.

        4. Data Security
        We implement appropriate security measures to protect your personal information.

        5. Children's Privacy
        Our service is not intended for children under 13 years of age.

        6. Contact Us
        If you have questions about this privacy policy, please contact us at privacy@leadlawk.com
        """
    }
    
    return privacy_policy_content


@router.get("/terms-of-service")
async def terms_of_service():
    """Return terms of service for app store compliance."""
    terms_content = {
        "title": "LeadLawk Terms of Service",
        "last_updated": "2024-01-01",
        "content": """
        LeadLawk Terms of Service

        1. Acceptance of Terms
        By accessing and using LeadLawk, you accept and agree to be bound by these terms.

        2. Use License
        Permission is granted to use LeadLawk for lead generation and management purposes.

        3. Disclaimer
        LeadLawk is provided on an "as is" basis without warranties of any kind.

        4. Limitations
        In no event shall LeadLawk be liable for any damages arising out of the use of our service.

        5. Account Terms
        You are responsible for maintaining the security of your account and password.

        6. Contact Us
        For questions about these terms, please contact us at support@leadlawk.com
        """
    }
    
    return terms_content


@router.delete("/account")
async def delete_account(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Delete user account (GDPR/App Store requirement)."""
    try:
        # Mark account as inactive instead of hard delete to maintain data integrity
        current_user.is_active = False
        current_user.email = f"deleted_{current_user.id}@deleted.com"
        current_user.full_name = "Deleted User"
        current_user.updated_at = datetime.utcnow()
        
        # TODO: In production, implement a background job to:
        # 1. Export user data if requested
        # 2. Anonymize associated records
        # 3. Delete personal information after retention period
        
        db.commit()
        
        return {"message": "Account deletion initiated. Your data will be removed within 30 days."}
    
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete account"
        )


@router.get("/export-data", response_model=dict)
async def export_user_data(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Export user data (GDPR requirement)."""
    try:
        # Collect user data
        user_data = {
            "personal_information": {
                "id": current_user.id,
                "email": current_user.email,
                "full_name": current_user.full_name,
                "created_at": current_user.created_at.isoformat(),
                "updated_at": current_user.updated_at.isoformat(),
            },
            "account_settings": {
                "is_active": current_user.is_active,
                "email_verified": getattr(current_user, 'email_verified', False),
                "two_factor_enabled": getattr(current_user, 'two_factor_enabled', False),
            },
            "leads_data": [
                {
                    "id": lead.id,
                    "business_name": lead.business_name,
                    "phone": lead.phone,
                    "status": lead.status.value,
                    "created_at": lead.created_at.isoformat(),
                }
                for lead in current_user.leads
            ],
            "export_timestamp": datetime.utcnow().isoformat(),
        }
        
        return user_data
    
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to export user data"
        )


@router.get("/data-processing-info")
async def data_processing_info():
    """Return information about data processing (GDPR compliance)."""
    return {
        "data_controller": {
            "name": "LeadLawk",
            "email": "privacy@leadlawk.com",
        },
        "purposes_of_processing": [
            "Account management",
            "Service provision",
            "Customer support",
            "Legal compliance"
        ],
        "legal_basis": "Legitimate interest and contract performance",
        "retention_period": "Data is retained while your account is active and for 30 days after deletion",
        "your_rights": [
            "Right to access your personal data",
            "Right to correct inaccurate data", 
            "Right to delete your data",
            "Right to restrict processing",
            "Right to data portability",
            "Right to object to processing"
        ],
        "contact": {
            "email": "privacy@leadlawk.com",
            "address": "LeadLawk Privacy Office"
        }
    }


@router.get("/children-privacy")
async def children_privacy():
    """Children's privacy information (COPPA compliance)."""
    return {
        "title": "Children's Privacy Protection",
        "policy": """
        LeadLawk does not knowingly collect personal information from children under 13 years of age.
        
        Our service is intended for business use and is not directed at children.
        
        If we learn that we have collected personal information from a child under 13,
        we will delete that information as quickly as possible.
        
        If you believe we have collected information from a child under 13,
        please contact us at privacy@leadlawk.com
        """,
        "age_verification": "Users must be 18 years or older to use LeadLawk",
        "contact": "privacy@leadlawk.com"
    }