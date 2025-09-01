"""
Enhanced Business Extractor Module with bulletproof extraction logic.
Uses semantic HTML patterns and structure-based identification.
Never relies on generated class names.
"""

from abc import ABC, abstractmethod
from typing import Dict, Optional, Any, List
from selenium.webdriver.common.by import By
from selenium.webdriver.support.wait import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException, NoSuchElementException
from selenium.webdriver.remote.webelement import WebElement
import re
import time


class SemanticExtractor:
    """Extraction using semantic HTML patterns only"""
    
    @staticmethod
    def extract_business_name(element: WebElement) -> Optional[str]:
        """Extract name using semantic patterns"""
        
        # Priority 1: aria-label on place links
        try:
            links = element.find_elements(By.CSS_SELECTOR, "a[href*='/maps/place/'][aria-label]")
            for link in links:
                aria_label = link.get_attribute("aria-label")
                if aria_label:
                    # Remove common suffixes
                    name = aria_label.split("·")[0].strip()
                    if SemanticExtractor._validate_name(name):
                        return name
        except:
            pass
            
        # Priority 2: Role=heading elements
        try:
            headings = element.find_elements(By.CSS_SELECTOR, "[role='heading']")
            for heading in headings:
                text = heading.text.strip()
                if text and SemanticExtractor._validate_name(text):
                    return text
        except:
            pass
            
        # Priority 3: Semantic heading tags
        for tag in ["h1", "h2", "h3", "h4"]:
            try:
                heads = element.find_elements(By.TAG_NAME, tag)
                for h in heads:
                    text = h.text.strip()
                    if text and SemanticExtractor._validate_name(text):
                        return text
            except:
                continue
                
        return None
        
    @staticmethod
    def extract_rating(element: WebElement) -> Dict[str, Any]:
        """Extract rating and review count"""
        result = {"rating": 0, "reviews": 0}
        
        # Look for role=img with aria-label containing rating
        try:
            imgs = element.find_elements(By.CSS_SELECTOR, "[role='img'][aria-label]")
            for img in imgs:
                label = img.get_attribute("aria-label")
                if label and "star" in label.lower():
                    # Extract rating
                    rating_match = re.search(r'(\d+\.?\d*)\s*star', label.lower())
                    if rating_match:
                        result["rating"] = float(rating_match.group(1))
                    
                    # Extract reviews
                    review_match = re.search(r'(\d+)\s*review', label.lower())
                    if review_match:
                        result["reviews"] = int(review_match.group(1))
                        
                    if result["rating"] and result["reviews"]:
                        return result
        except:
            pass
            
        return result
        
    @staticmethod
    def extract_website(element: WebElement) -> Optional[str]:
        """Extract website URL"""
        
        # Check data-value="Website" (most reliable)
        try:
            websites = element.find_elements(By.CSS_SELECTOR, 'a[data-value="Website"]')
            for site in websites:
                href = site.get_attribute("href")
                if href and "google.com" not in href:
                    return href
        except:
            pass
            
        # Check aria-label containing Website
        try:
            sites = element.find_elements(By.CSS_SELECTOR, 'a[aria-label*="Website"]')
            for site in sites:
                href = site.get_attribute("href")
                if href and "http" in href and "google.com" not in href:
                    return href
        except:
            pass
            
        return None
        
    @staticmethod
    def extract_phone(element: WebElement) -> Optional[str]:
        """Extract phone number"""
        patterns = [
            r'\(\d{3}\)\s?\d{3}-\d{4}',
            r'\d{3}-\d{3}-\d{4}',
            r'\+1\s?\d{3}\s?\d{3}\s?\d{4}',
        ]
        
        try:
            texts = element.find_elements(By.CSS_SELECTOR, "span, div")
            for txt in texts:
                content = txt.text.strip()
                for pattern in patterns:
                    match = re.search(pattern, content)
                    if match:
                        return match.group(0)
        except:
            pass
            
        return None
        
    @staticmethod
    def is_compact_listing(element: WebElement) -> bool:
        """Check if listing requires click for details"""
        
        # Standard listings have visible action buttons
        action_buttons = [
            'a[data-value="Website"]',
            'a[data-value="Directions"]',
            'button[data-value]',
        ]
        
        for selector in action_buttons:
            try:
                if element.find_elements(By.CSS_SELECTOR, selector):
                    return False  # Has buttons = standard
            except:
                pass
                
        # Must be a valid business listing
        try:
            place_links = element.find_elements(By.CSS_SELECTOR, "a[href*='/maps/place/']")
            return len(place_links) > 0  # Has place link but no buttons = compact
        except:
            return False
            
    @staticmethod
    def _validate_name(text: str) -> bool:
        """Validate business name"""
        if not text or len(text) < 2:
            return False
            
        # Filter out UI elements
        ui_words = ["website", "directions", "call", "save", "open", "closed"]
        if text.lower() in ui_words:
            return False
            
        # Must contain letters
        return bool(re.search(r'[a-zA-Z]', text))


class EnhancedBusinessExtractor:
    """Main extractor with bulletproof logic"""
    
    def __init__(self, driver=None):
        self.driver = driver
        self.extractor = SemanticExtractor()
        
    def extract(self, element: WebElement) -> Dict[str, Any]:
        """Extract all business data"""
        
        # Core extraction
        data = {
            "name": self.extractor.extract_business_name(element),
            "phone": self.extractor.extract_phone(element),
            "website": self.extractor.extract_website(element),
            "has_website": False,
            "is_compact": self.extractor.is_compact_listing(element),
        }
        
        # Set website presence
        data["has_website"] = bool(data["website"])
        
        # Extract rating
        rating_data = self.extractor.extract_rating(element)
        data.update(rating_data)
        
        # Extract Maps URL
        try:
            link = element.find_element(By.CSS_SELECTOR, "a[href*='/maps/place/']")
            data["url"] = link.get_attribute("href")
        except:
            data["url"] = None
            
        # Handle compact listings with click-through
        if data["is_compact"] and self.driver and not data["website"]:
            website = self._check_website_via_click(element, data["name"])
            if website:
                data["website"] = website
                data["has_website"] = True
                
        return data
        
    def _check_website_via_click(self, element: WebElement, name: str) -> Optional[str]:
        """Click into compact listing to check for website"""
        
        if not self.driver:
            return None
            
        try:
            # Find and click the business link
            link = element.find_element(By.CSS_SELECTOR, "a[href*='/maps/place/']")
            self.driver.execute_script("arguments[0].click();", link)
            time.sleep(2)
            
            # Look for website in expanded view
            website = self.extractor.extract_website(self.driver)
            
            # Navigate back
            self.driver.back()
            time.sleep(2)
            
            return website
            
        except Exception as e:
            print(f"Click-through failed: {e}")
            try:
                self.driver.back()
            except:
                pass
            return None


def extract_business_bulletproof(element: WebElement, driver=None) -> Dict[str, Any]:
    """Main entry point for bulletproof extraction"""
    extractor = EnhancedBusinessExtractor(driver)
    return extractor.extract(element)