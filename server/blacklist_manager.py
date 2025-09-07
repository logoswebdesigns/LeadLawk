"""
Blacklist Manager Module
Manages blacklisted businesses to prevent scraping known franchises and big companies.
"""

from typing import List, Optional
from sqlalchemy.orm import Session
from models import BlacklistedBusiness
from datetime import datetime, timezone
import logging

logger = logging.getLogger(__name__)


class BlacklistManager:
    """Manages blacklisted businesses with exact name matching"""
    
    def __init__(self, db_session: Session):
        self.session = db_session
    
    def add_to_blacklist(self, business_name: str, reason: str = 'too_big', notes: str = None) -> bool:
        """
        Add exact business name to blacklist.
        
        Args:
            business_name: Exact name of business to blacklist
            reason: Reason for blacklisting ('too_big', 'franchise', 'did_not_convert')
            notes: Optional notes about why business was blacklisted
            
        Returns:
            True if added successfully, False if already exists
        """
        try:
            # Check if already blacklisted
            existing = self.session.query(BlacklistedBusiness).filter(
                BlacklistedBusiness.business_name == business_name
            ).first()
            
            if existing:
                logger.info(f"Business '{business_name}' already in blacklist")
                return False
            
            # Add to blacklist
            blacklisted = BlacklistedBusiness(
                business_name=business_name,
                reason=reason,
                notes=notes
            )
            self.session.add(blacklisted)
            self.session.commit()
            
            logger.info(f"Added '{business_name}' to blacklist (reason: {reason})")
            return True
            
        except Exception as e:
            logger.error(f"Error adding '{business_name}' to blacklist: {str(e)}")
            self.session.rollback()
            return False
    
    def is_blacklisted(self, business_name: str) -> bool:
        """
        Check if exact business name is blacklisted.
        
        Args:
            business_name: Exact name of business to check
            
        Returns:
            True if blacklisted, False otherwise
        """
        try:
            exists = self.session.query(BlacklistedBusiness).filter(
                BlacklistedBusiness.business_name == business_name
            ).first() is not None
            
            if exists:
                logger.debug(f"Business '{business_name}' is blacklisted")
            
            return exists
            
        except Exception as e:
            logger.error(f"Error checking blacklist for '{business_name}': {str(e)}")
            return False
    
    def remove_from_blacklist(self, business_name: str) -> bool:
        """
        Remove exact business name from blacklist.
        
        Args:
            business_name: Exact name of business to remove
            
        Returns:
            True if removed successfully, False otherwise
        """
        try:
            deleted = self.session.query(BlacklistedBusiness).filter(
                BlacklistedBusiness.business_name == business_name
            ).delete()
            
            if deleted:
                self.session.commit()
                logger.info(f"Removed '{business_name}' from blacklist")
                return True
            else:
                logger.info(f"Business '{business_name}' not found in blacklist")
                return False
                
        except Exception as e:
            logger.error(f"Error removing '{business_name}' from blacklist: {str(e)}")
            self.session.rollback()
            return False
    
    def get_all_blacklisted(self) -> List[BlacklistedBusiness]:
        """
        Get all blacklisted businesses.
        
        Returns:
            List of BlacklistedBusiness objects
        """
        try:
            return self.session.query(BlacklistedBusiness).order_by(
                BlacklistedBusiness.created_at.desc()
            ).all()
        except Exception as e:
            logger.error(f"Error retrieving blacklist: {str(e)}")
            return []
    
    def get_blacklist_count(self) -> int:
        """
        Get count of blacklisted businesses.
        
        Returns:
            Number of blacklisted businesses
        """
        try:
            return self.session.query(BlacklistedBusiness).count()
        except Exception as e:
            logger.error(f"Error counting blacklist: {str(e)}")
            return 0
    
    def bulk_add_to_blacklist(self, businesses: List[dict]) -> int:
        """
        Add multiple businesses to blacklist.
        
        Args:
            businesses: List of dicts with 'name', 'reason', and optional 'notes'
            
        Returns:
            Number of businesses successfully added
        """
        added_count = 0
        
        for business in businesses:
            name = business.get('name')
            reason = business.get('reason', 'franchise')
            notes = business.get('notes')
            
            if name and self.add_to_blacklist(name, reason, notes):
                added_count += 1
        
        return added_count


# Pre-defined list of known franchises and big companies
KNOWN_FRANCHISES = [
    # Fast Food
    {"name": "McDonald's", "reason": "franchise", "notes": "Global fast food chain"},
    {"name": "Subway", "reason": "franchise", "notes": "Sandwich franchise"},
    {"name": "Burger King", "reason": "franchise", "notes": "Fast food chain"},
    {"name": "Wendy's", "reason": "franchise", "notes": "Fast food chain"},
    {"name": "Taco Bell", "reason": "franchise", "notes": "Fast food chain"},
    {"name": "KFC", "reason": "franchise", "notes": "Fast food chain"},
    {"name": "Pizza Hut", "reason": "franchise", "notes": "Pizza chain"},
    {"name": "Domino's Pizza", "reason": "franchise", "notes": "Pizza chain"},
    {"name": "Papa John's", "reason": "franchise", "notes": "Pizza chain"},
    {"name": "Chick-fil-A", "reason": "franchise", "notes": "Fast food chain"},
    {"name": "Starbucks", "reason": "franchise", "notes": "Coffee chain"},
    {"name": "Dunkin'", "reason": "franchise", "notes": "Coffee and donut chain"},
    {"name": "Chipotle", "reason": "franchise", "notes": "Fast casual chain"},
    {"name": "Panera Bread", "reason": "franchise", "notes": "Bakery cafe chain"},
    {"name": "Five Guys", "reason": "franchise", "notes": "Burger chain"},
    {"name": "Jimmy John's", "reason": "franchise", "notes": "Sandwich chain"},
    {"name": "Arby's", "reason": "franchise", "notes": "Fast food chain"},
    {"name": "Sonic Drive-In", "reason": "franchise", "notes": "Fast food chain"},
    {"name": "Dairy Queen", "reason": "franchise", "notes": "Fast food chain"},
    
    # Retail
    {"name": "Walmart", "reason": "too_big", "notes": "Retail giant"},
    {"name": "Target", "reason": "too_big", "notes": "Retail chain"},
    {"name": "Costco", "reason": "too_big", "notes": "Warehouse club"},
    {"name": "Sam's Club", "reason": "too_big", "notes": "Warehouse club"},
    {"name": "Home Depot", "reason": "too_big", "notes": "Home improvement chain"},
    {"name": "Lowe's", "reason": "too_big", "notes": "Home improvement chain"},
    {"name": "CVS", "reason": "franchise", "notes": "Pharmacy chain"},
    {"name": "CVS Pharmacy", "reason": "franchise", "notes": "Pharmacy chain"},
    {"name": "Walgreens", "reason": "franchise", "notes": "Pharmacy chain"},
    {"name": "Rite Aid", "reason": "franchise", "notes": "Pharmacy chain"},
    {"name": "Best Buy", "reason": "too_big", "notes": "Electronics chain"},
    {"name": "Dollar General", "reason": "franchise", "notes": "Discount store chain"},
    {"name": "Dollar Tree", "reason": "franchise", "notes": "Discount store chain"},
    {"name": "Family Dollar", "reason": "franchise", "notes": "Discount store chain"},
    
    # Auto Services
    {"name": "Jiffy Lube", "reason": "franchise", "notes": "Oil change chain"},
    {"name": "Midas", "reason": "franchise", "notes": "Auto repair chain"},
    {"name": "Firestone", "reason": "franchise", "notes": "Tire and auto chain"},
    {"name": "Meineke", "reason": "franchise", "notes": "Auto repair chain"},
    {"name": "Maaco", "reason": "franchise", "notes": "Auto painting chain"},
    {"name": "AAMCO", "reason": "franchise", "notes": "Transmission repair chain"},
    {"name": "Discount Tire", "reason": "franchise", "notes": "Tire chain"},
    {"name": "NTB", "reason": "franchise", "notes": "Tire chain"},
    {"name": "Valvoline", "reason": "franchise", "notes": "Oil change chain"},
    {"name": "AutoZone", "reason": "franchise", "notes": "Auto parts chain"},
    {"name": "O'Reilly Auto Parts", "reason": "franchise", "notes": "Auto parts chain"},
    {"name": "Advance Auto Parts", "reason": "franchise", "notes": "Auto parts chain"},
    
    # Services
    {"name": "H&R Block", "reason": "franchise", "notes": "Tax preparation chain"},
    {"name": "Jackson Hewitt", "reason": "franchise", "notes": "Tax preparation chain"},
    {"name": "Liberty Tax", "reason": "franchise", "notes": "Tax preparation chain"},
    {"name": "The UPS Store", "reason": "franchise", "notes": "Shipping franchise"},
    {"name": "FedEx Office", "reason": "franchise", "notes": "Shipping and printing"},
    {"name": "PostNet", "reason": "franchise", "notes": "Shipping franchise"},
    {"name": "Great Clips", "reason": "franchise", "notes": "Hair salon chain"},
    {"name": "Supercuts", "reason": "franchise", "notes": "Hair salon chain"},
    {"name": "Sport Clips", "reason": "franchise", "notes": "Hair salon chain"},
    {"name": "Massage Envy", "reason": "franchise", "notes": "Spa franchise"},
    
    # Fitness
    {"name": "Planet Fitness", "reason": "franchise", "notes": "Gym chain"},
    {"name": "Anytime Fitness", "reason": "franchise", "notes": "Gym franchise"},
    {"name": "Orange Theory", "reason": "franchise", "notes": "Fitness franchise"},
    {"name": "Snap Fitness", "reason": "franchise", "notes": "Gym franchise"},
    {"name": "LA Fitness", "reason": "franchise", "notes": "Gym chain"},
    
    # Hotels
    {"name": "Marriott", "reason": "franchise", "notes": "Hotel chain"},
    {"name": "Hilton", "reason": "franchise", "notes": "Hotel chain"},
    {"name": "Holiday Inn", "reason": "franchise", "notes": "Hotel chain"},
    {"name": "Hampton Inn", "reason": "franchise", "notes": "Hotel chain"},
    {"name": "Best Western", "reason": "franchise", "notes": "Hotel chain"},
    {"name": "Days Inn", "reason": "franchise", "notes": "Hotel chain"},
    {"name": "Motel 6", "reason": "franchise", "notes": "Hotel chain"},
    {"name": "Super 8", "reason": "franchise", "notes": "Hotel chain"},
    
    # Gas Stations / Convenience
    {"name": "Shell", "reason": "franchise", "notes": "Gas station chain"},
    {"name": "Exxon", "reason": "franchise", "notes": "Gas station chain"},
    {"name": "Mobil", "reason": "franchise", "notes": "Gas station chain"},
    {"name": "Chevron", "reason": "franchise", "notes": "Gas station chain"},
    {"name": "BP", "reason": "franchise", "notes": "Gas station chain"},
    {"name": "Texaco", "reason": "franchise", "notes": "Gas station chain"},
    {"name": "Circle K", "reason": "franchise", "notes": "Convenience store chain"},
    {"name": "7-Eleven", "reason": "franchise", "notes": "Convenience store chain"},
]


def initialize_blacklist(db_session: Session) -> int:
    """
    Initialize blacklist with known franchises.
    
    Args:
        db_session: Database session
        
    Returns:
        Number of businesses added to blacklist
    """
    manager = BlacklistManager(db_session)
    added_count = manager.bulk_add_to_blacklist(KNOWN_FRANCHISES)
    logger.info(f"Initialized blacklist with {added_count} known franchises")
    return added_count