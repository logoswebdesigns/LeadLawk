"""
Business Extractor Module
Handles extraction of business details from different Google Maps listing types.
Follows SOLID principles for extensibility and maintainability.
"""

from abc import ABC, abstractmethod
from typing import Dict, Optional, Any
from selenium.webdriver.common.by import By
from selenium.webdriver.support.wait import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException, NoSuchElementException
import re
import time


class BusinessExtractor(ABC):
    """Abstract base class for business extraction strategies"""
    
    @abstractmethod
    def can_handle(self, element) -> bool:
        """Check if this extractor can handle the given element"""
        pass
    
    @abstractmethod
    def extract(self, element, driver=None) -> Dict[str, Any]:
        """Extract business details from the element"""
        pass


class StandardListingExtractor(BusinessExtractor):
    """Extractor for standard business listings (e.g., painters, restaurants)"""
    
    def can_handle(self, element) -> bool:
        """Check if element has visible Website button or action buttons"""
        try:
            # Primary check: Look for Website button with data-value attribute (most stable)
            website_btn = element.find_element(By.CSS_SELECTOR, "a[data-value='Website']")
            print(f"    🔍 StandardListingExtractor: Found Website button - STANDARD LISTING")
            return True
        except:
            # Secondary check: Look for Directions button (also stable data-value attribute)
            try:
                directions_btn = element.find_element(By.CSS_SELECTOR, "[data-value='Directions']")
                print(f"    🔍 StandardListingExtractor: Found Directions button - STANDARD LISTING")
                return True
            except:
                # Tertiary check: Look for non-empty Rwjeuc container with action buttons inside
                try:
                    rwjeuc_container = element.find_element(By.CSS_SELECTOR, ".Rwjeuc")
                    # Check if container has action buttons inside (standard) vs empty (compact)
                    action_buttons_in_container = rwjeuc_container.find_elements(By.CSS_SELECTOR, "a, button")
                    if action_buttons_in_container:
                        print(f"    🔍 StandardListingExtractor: Found Rwjeuc container with {len(action_buttons_in_container)} action buttons - STANDARD LISTING")
                        return True
                    else:
                        print(f"    🔍 StandardListingExtractor: Found empty Rwjeuc container - NOT STANDARD")
                        return False
                except:
                    print(f"    🔍 StandardListingExtractor: No Rwjeuc container found - NOT STANDARD")
                    return False
    
    def extract(self, element, driver=None) -> Dict[str, Any]:
        """Extract business details from standard listing"""
        details = self._extract_basic_info(element)
        
        # Website detection for standard listing
        try:
            website_elem = element.find_element(By.CSS_SELECTOR, "a[data-value='Website']")
            details['website'] = website_elem.get_attribute("href")
            details['has_website'] = True
            print(f"    🌐 Found website in standard listing: {details['website'][:50]}...")
        except:
            details['website'] = None
            details['has_website'] = False
            print(f"    ❌ No website button found in standard listing")
        
        return details
    
    def _extract_basic_info(self, element) -> Dict[str, Any]:
        """Extract common business information"""
        details = {}
        
        # Business name
        try:
            name_elem = element.find_element(By.CSS_SELECTOR, ".qBF1Pd.fontHeadlineSmall")
            details['name'] = name_elem.text.strip()
        except:
            try:
                link_elem = element.find_element(By.CSS_SELECTOR, "a.hfpxzc")
                details['name'] = link_elem.get_attribute("aria-label")
                if details['name']:
                    # Clean up aria-label (might contain "· Visited link")
                    details['name'] = details['name'].split("·")[0].strip()
            except:
                details['name'] = "Unknown Business"
        
        # Rating and Reviews
        try:
            rating_container = element.find_element(By.CSS_SELECTOR, "span.ZkP5Je[aria-label]")
            aria_label = rating_container.get_attribute("aria-label")
            
            if aria_label:
                rating_match = re.search(r'^([\d\.]+)\s+stars?', aria_label)
                if rating_match:
                    details['rating'] = rating_match.group(1)
                else:
                    details['rating'] = "0"
                
                review_match = re.search(r'(\d[\d,]*)\s+Reviews?', aria_label)
                if review_match:
                    details['reviews'] = review_match.group(1).replace(',', '')
                else:
                    details['reviews'] = "0"
            else:
                details['rating'] = "0"
                details['reviews'] = "0"
        except:
            details['rating'] = "0"
            details['reviews'] = "0"
        
        # Phone
        try:
            phone_elem = element.find_element(By.CSS_SELECTOR, "span.UsdlK")
            details['phone'] = phone_elem.text.strip()
        except:
            details['phone'] = None
        
        # URL
        try:
            link_elem = element.find_element(By.CSS_SELECTOR, "a.hfpxzc")
            details['url'] = link_elem.get_attribute("href")
        except:
            details['url'] = None
        
        # Photos
        try:
            photo_elements = element.find_elements(By.CSS_SELECTOR, "img[src*='googleusercontent']")
            details['photo_count'] = len(photo_elements)
        except:
            details['photo_count'] = 0
        
        # Description
        try:
            desc_parts = []
            for class_name in [".W4Efsd", ".fontBodyMedium"]:
                desc_elems = element.find_elements(By.CSS_SELECTOR, class_name)
                for elem in desc_elems:
                    text = elem.text.strip()
                    if text and text not in desc_parts:
                        desc_parts.append(text)
            
            details['description'] = '\n'.join(desc_parts[:3]) if desc_parts else ""
            details['description_length'] = len(details['description'])
        except:
            details['description'] = ""
            details['description_length'] = 0
        
        # Default values
        details['has_recent_reviews'] = True
        details['last_review_date'] = None
        
        return details


class CompactListingExtractor(BusinessExtractor):
    """Extractor for compact listings that require clicking to see details (e.g., barber shops)"""
    
    def can_handle(self, element) -> bool:
        """Check if this is a compact listing that requires click-through"""
        try:
            # If has Website or Directions buttons visible, it's standard (not compact)
            standard_buttons = element.find_elements(By.CSS_SELECTOR, "a[data-value='Website'], [data-value='Directions']")
            if standard_buttons:
                print(f"    🔍 CompactListingExtractor: Found {len(standard_buttons)} standard action buttons - NOT COMPACT")
                return False
            
            print(f"    🔍 CompactListingExtractor: No standard action buttons - checking Rwjeuc container")
            
            # Key test: Check for empty Rwjeuc container (compact) vs filled container (standard)  
            try:
                rwjeuc_container = element.find_element(By.CSS_SELECTOR, ".Rwjeuc")
                action_buttons_in_container = rwjeuc_container.find_elements(By.CSS_SELECTOR, "a, button")
                
                if action_buttons_in_container:
                    # Has content in Rwjeuc = standard listing
                    print(f"    🔍 CompactListingExtractor: Rwjeuc container has {len(action_buttons_in_container)} buttons - NOT COMPACT")
                    return False
                else:
                    # Empty Rwjeuc = compact listing
                    print(f"    🔍 CompactListingExtractor: Empty Rwjeuc container - checking for business elements")
                    
                    # Verify it's a valid business listing
                    business_links = element.find_elements(By.CSS_SELECTOR, "a[href*='/maps/place/']")
                    name_elements = element.find_elements(By.CSS_SELECTOR, ".qBF1Pd, .fontHeadlineSmall")
                    
                    if business_links and name_elements:
                        print(f"    🔍 CompactListingExtractor: Empty Rwjeuc + business elements = COMPACT LISTING")
                        return True
                    else:
                        print(f"    🔍 CompactListingExtractor: Missing business elements - NOT COMPACT")
                        return False
                        
            except:
                print(f"    🔍 CompactListingExtractor: No Rwjeuc container - NOT COMPACT")
                return False
                
        except Exception as e:
            print(f"    🔍 CompactListingExtractor: Error in can_handle: {e} - NOT COMPACT")
            return False
    
    def extract(self, element, driver=None) -> Dict[str, Any]:
        """Extract business details from compact listing, including click-through for website"""
        details = StandardListingExtractor()._extract_basic_info(element)
        
        # For compact listings, we need to click to check for website
        if driver:
            website_url = self._check_website_via_click(element, driver, details.get('name', 'Unknown'))
            if website_url:
                details['website'] = website_url
                details['has_website'] = True
                print(f"    🌐 Found website via click-through: {website_url}")
            else:
                details['website'] = None
                details['has_website'] = False
                print(f"    ❌ No website found after click-through")
        else:
            # Without driver, we can't click to check
            details['website'] = None
            details['has_website'] = False
            details['_needs_click_check'] = True
            print(f"    ⚠️ Compact listing - website check requires click-through")
        
        return details
    
    def _check_website_via_click(self, element, driver, business_name: str) -> Optional[str]:
        """Click into the business to check for website information using stable selectors"""
        try:
            print(f"    🖱️ Clicking into {business_name} to check for website...")
            
            # Find business link using more stable selector
            link_elem = element.find_element(By.CSS_SELECTOR, "a[href*='/maps/place/']")
            original_url = driver.current_url
            
            # Click to open business details
            driver.execute_script("arguments[0].click();", link_elem)
            time.sleep(2)  # Wait for page to load
            
            # Look for website in the detailed view using stable approaches
            website_url = None
            
            # Method 1: Look for Website button with data-value (most stable)
            try:
                website_btn = driver.find_element(By.CSS_SELECTOR, "a[data-value='Website']")
                href = website_btn.get_attribute("href")
                if href and not href.startswith("https://www.google.com"):
                    website_url = href
                    print(f"    ✅ Found website via data-value Website button: {website_url}")
            except:
                pass
            
            # Method 2: Look for any external link that's not Google
            if not website_url:
                try:
                    external_links = driver.find_elements(By.CSS_SELECTOR, "a[href*='://']:not([href*='google.com']):not([href*='maps'])")
                    for link in external_links:
                        href = link.get_attribute("href")
                        if href and ('http' in href) and not any(domain in href for domain in ['google', 'youtube', 'facebook', 'instagram', 'twitter']):
                            # Looks like a business website
                            website_url = href
                            print(f"    ✅ Found website via external link: {website_url}")
                            break
                except:
                    pass
            
            # Method 3: Look for text that looks like a website domain
            if not website_url:
                try:
                    # Look for text elements that contain domain-like strings
                    text_elements = driver.find_elements(By.CSS_SELECTOR, "span, div, p")
                    for elem in text_elements:
                        text = elem.text.strip()
                        if text and '.' in text and len(text.split('.')) >= 2:
                            # Check if it looks like a domain (simple heuristic)
                            if (text.endswith('.com') or text.endswith('.net') or text.endswith('.org')) and ' ' not in text and len(text) > 4:
                                website_url = f"https://{text}" if not text.startswith('http') else text
                                print(f"    ✅ Found website via domain text: {website_url}")
                                break
                except:
                    pass
            
            # Method 4: Look for aria-label containing website info
            if not website_url:
                try:
                    website_elements = driver.find_elements(By.CSS_SELECTOR, "[aria-label*='website'], [aria-label*='Website']")
                    for elem in website_elements:
                        if elem.tag_name == 'a':
                            href = elem.get_attribute("href")
                            if href and 'http' in href:
                                website_url = href
                                print(f"    ✅ Found website via aria-label: {website_url}")
                                break
                except:
                    pass
            
            # Navigate back to the list
            print(f"    🔙 Navigating back to search results...")
            driver.back()
            time.sleep(2)  # Wait for page to reload
            
            # Verify we're back at the search results using stable selector
            WebDriverWait(driver, 5).until(
                EC.presence_of_element_located((By.CSS_SELECTOR, "[role='feed'], [role='main']"))
            )
            
            return website_url
            
        except Exception as e:
            print(f"    ❌ Error checking website via click: {e}")
            # Try to recover by going back
            try:
                driver.back()
                time.sleep(1)
            except:
                pass
            return None


class BusinessExtractorFactory:
    """Factory class to select the appropriate extractor"""
    
    def __init__(self, driver=None):
        self.driver = driver
        self.extractors = [
            StandardListingExtractor(),
            CompactListingExtractor()
        ]
    
    def extract(self, element) -> Dict[str, Any]:
        """Extract business details using the appropriate strategy"""
        for extractor in self.extractors:
            if extractor.can_handle(element):
                print(f"    📦 Using {extractor.__class__.__name__}")
                return extractor.extract(element, self.driver)
        
        # Fallback to standard extractor if no specific handler found
        print(f"    📦 Using default StandardListingExtractor")
        return self.extractors[0].extract(element, self.driver)


def extract_business_details(element, driver=None, enable_click_through=True) -> Dict[str, Any]:
    """
    Main entry point for extracting business details.
    
    Args:
        element: The web element containing the business listing
        driver: Optional Selenium driver for click-through operations
        enable_click_through: Whether to enable clicking into businesses for additional info
    
    Returns:
        Dictionary containing business details
    """
    factory = BusinessExtractorFactory(driver if enable_click_through else None)
    return factory.extract(element)