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
                # Tertiary check: Look for any action buttons with data-value
                try:
                    action_buttons = element.find_elements(By.CSS_SELECTOR, "a[data-value], button[data-value]")
                    if action_buttons:
                        print(f"    🔍 StandardListingExtractor: Found {len(action_buttons)} action buttons - STANDARD LISTING")
                        return True
                    
                    print(f"    🔍 StandardListingExtractor: No action buttons found - NOT STANDARD")
                    return False
                except:
                    print(f"    🔍 StandardListingExtractor: No action buttons found - NOT STANDARD")
                    return False
    
    def extract(self, element, driver=None) -> Dict[str, Any]:
        """Extract business details from standard listing"""
        details = self._extract_basic_info(element)
        
        # Website detection for standard listing
        try:
            website_elem = element.find_element(By.CSS_SELECTOR, "a[data-value='Website']")
            details['website'] = website_elem.get_attribute("href")
            details['has_website'] = True
            business_name = details.get('name', 'Unknown Business')
            print(f"    🌐 Found website for {business_name}: {details['website'][:50]}...")
        except:
            details['website'] = None
            details['has_website'] = False
            business_name = details.get('name', 'Unknown Business')
            print(f"    ❌ No website button found for {business_name}")
        
        return details
    
    def _extract_basic_info(self, element) -> Dict[str, Any]:
        """Extract common business information"""
        details = {}
        
        # DEBUG: Print actual HTML structure to understand what we're working with
        try:
            element_html = element.get_attribute('innerHTML')[:500]  # First 500 chars
            print(f"    🔍 DEBUG HTML: {element_html}...")
        except:
            print("    🔍 DEBUG: Could not get element HTML")
        
        # Business name - using semantic HTML structure patterns (avoid generated class names)
        business_name = None
        name_selectors = [
            # Primary: Semantic structure-based selectors
            "a[href*='/maps/place/'][aria-label]",          # Maps link with aria-label (most reliable)
            "div.qBF1Pd",                                    # Specific business name class found in reference HTML
            "div[class*='fontHeadline']",                   # Any div with semantic fontHeadline class
            "div[class*='headline']",                       # Any div with headline in class name
            
            # Secondary: Maps link patterns
            "a[href*='/maps/place/']",                      # Any Maps place link  
            "a[aria-label]",                                # Any link with aria-label
            
            # Tertiary: True semantic HTML patterns
            "h1", "h2", "h3", "h4", "h5", "h6",            # Semantic headings
            "[role='heading']",                             # ARIA heading role
            
            # Last resort: Broad content filtering
            "div", "span"                                   # Any div/span (filtered by content)
        ]
        
        for selector in name_selectors:
            try:
                if "href*=" in selector and "/maps/place/" in selector:
                    # Special handling for business link - try aria-label first, then text
                    link_elems = element.find_elements(By.CSS_SELECTOR, selector)
                    for link_elem in link_elems:
                        href = link_elem.get_attribute("href")
                        if href and '/maps/place/' in href:
                            aria_label = link_elem.get_attribute("aria-label")
                            if aria_label:
                                candidate_name = aria_label.split("·")[0].strip()
                                if self._is_valid_business_name(candidate_name) and len(candidate_name) > 3:
                                    business_name = candidate_name
                                    print(f"    🏷️ Found name via aria-label {selector}: '{business_name}'")
                                    break
                            
                            # Try text content only for Maps place links
                            text_content = link_elem.text.strip()
                            if text_content and self._is_valid_business_name(text_content) and len(text_content) > 3:
                                business_name = text_content
                                print(f"    🏷️ Found name via text {selector}: '{business_name}'")
                                break
                    if business_name:
                        break
                else:
                    # Regular text extraction with filtering - check multiple elements
                    name_elems = element.find_elements(By.CSS_SELECTOR, selector)
                    for name_elem in name_elems:
                        candidate_name = name_elem.text.strip()
                        if candidate_name and self._is_valid_business_name(candidate_name):
                            # Additional check: business names should be substantial
                            if len(candidate_name) >= 3 and not candidate_name.lower() in ['div', 'span', 'click', 'view', 'more']:
                                business_name = candidate_name
                                print(f"    🏷️ Found name via {selector}: '{business_name}'")
                                break
                    if business_name:
                        break
            except Exception as e:
                print(f"    🔍 Selector {selector} failed: {str(e)[:100]}...")
                continue
        
        details['name'] = business_name if business_name else "Unknown Business"
        if not business_name:
            print(f"    ❌ No business name found with any selector!")
        
        # Rating and Reviews - semantic patterns avoiding generated class names
        rating_selectors = [
            # Primary: Semantic ARIA patterns (most reliable)
            "span[role='img'][aria-label*='stars']",                # Role=img with stars in aria-label
            "span[role='img'][aria-label*='Reviews']",              # Role=img with Reviews in aria-label
            "[role='img'][aria-label*='stars']",                    # Any element with role=img + stars
            "[role='img'][aria-label*='Reviews']",                  # Any element with role=img + Reviews
            
            # Secondary: Broader ARIA patterns  
            "*[aria-label*='stars']",                               # Any element with "stars" in aria-label
            "*[aria-label*='star']",                                # Any element with "star" in aria-label  
            "*[aria-label*='Reviews']",                             # Any element with "Reviews" in aria-label
            "*[aria-label*='reviews']",                             # Any element with "reviews" in aria-label
            "*[aria-label*='Rating']",                              # Any element with "Rating" in aria-label
            "*[aria-label*='rating']",                              # Any element with "rating" in aria-label
            
            # Tertiary: Semantic role-based patterns
            "[role='img']",                                         # Any element with role=img (star ratings)
            "span[role='img']",                                     # Span with role=img
            "[data-rating]",                                        # Data attribute for ratings
            "[title*='star']",                                      # Title attribute mentioning stars
            
            # Last resort: Content-filtered broad patterns
            "span", "div"                                           # Any span/div (filtered by content)
        ]
        
        rating_found = False
        for rating_selector in rating_selectors:
            try:
                rating_containers = element.find_elements(By.CSS_SELECTOR, rating_selector)
                for rating_container in rating_containers:
                    aria_label = rating_container.get_attribute("aria-label")
                    if aria_label:
                        print(f"    ⭐ Found rating aria-label via {rating_selector}: '{aria_label}'")
                        
                        # Try multiple rating patterns
                        rating_patterns = [
                            r'(\d+\.?\d*)\s*stars?',           # "4.5 stars"
                            r'(\d+\.?\d*)\s*out of',           # "4.5 out of"
                            r'^(\d+\.?\d*)\s',                 # "4.5 "
                            r'Rating:\s*(\d+\.?\d*)',          # "Rating: 4.5"
                        ]
                        
                        for pattern in rating_patterns:
                            rating_match = re.search(pattern, aria_label.lower())
                            if rating_match:
                                potential_rating = float(rating_match.group(1))
                                if 0 <= potential_rating <= 5:  # Valid rating range
                                    details['rating'] = potential_rating
                                    print(f"    ⭐ Extracted rating: {details['rating']}")
                                    rating_found = True
                                    break
                        
                        # Extract review count
                        review_match = re.search(r'(\d+)\s*reviews?', aria_label.lower())
                        if review_match:
                            details['reviews'] = int(review_match.group(1))
                            print(f"    📝 Extracted reviews: {details['reviews']}")
                        
                        if rating_found:
                            break
                    
                    # Try text content as fallback
                    text_content = rating_container.text.strip()
                    if text_content and re.search(r'\d+\.?\d*', text_content):
                        rating_match = re.search(r'(\d+\.?\d*)', text_content)
                        if rating_match:
                            potential_rating = float(rating_match.group(1))
                            if 0 <= potential_rating <= 5:
                                details['rating'] = potential_rating
                                print(f"    ⭐ Extracted rating from text: {details['rating']}")
                                rating_found = True
                                break
                
                if rating_found:
                    break
            except Exception as e:
                print(f"    🔍 Rating selector {rating_selector} failed: {str(e)[:100]}...")
                continue
        
        if not rating_found:
            details['rating'] = "0"
            details['reviews'] = "0"
            print(f"    ❌ No rating found with any selector")
        
        # Phone
        try:
            # First try the specific phone class found in reference HTML
            phone_elem = element.find_element(By.CSS_SELECTOR, "span.UsdlK")
            details['phone'] = phone_elem.text.strip()
        except:
            try:
                # Fallback to pattern matching in spans
                phone_elems = element.find_elements(By.CSS_SELECTOR, "span")
                phone_pattern = r'\(\d{3}\)\s?\d{3}-\d{4}|\d{3}-\d{3}-\d{4}|\+?1?\s?\(\d{3}\)\s?\d{3}-\d{4}'
                for elem in phone_elems:
                    text = elem.text.strip()
                    if re.search(phone_pattern, text):
                        details['phone'] = text
                        break
                else:
                    details['phone'] = None
            except:
                details['phone'] = None
        
        # URL  
        try:
            # Look for main Google Maps place link using semantic selector
            link_elem = element.find_element(By.CSS_SELECTOR, "a[href*='/maps/place/'][aria-label]")
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
            # Use semantic selectors to find description text
            for selector in ["span", "div p", "div span", "[aria-label] ~ span", "div:not([role]) span"]:
                desc_elems = element.find_elements(By.CSS_SELECTOR, selector)
                for elem in desc_elems:
                    text = elem.text.strip()
                    if text and text not in desc_parts and len(text) > 10:  # Filter out short/meaningless text
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
    
    def _is_valid_business_name(self, text: str) -> bool:
        """Check if text looks like a valid business name"""
        if not text or len(text.strip()) < 2:
            return False
        
        # Filter out common non-business text
        invalid_patterns = [
            r'^\d+\s*(am|pm|AM|PM)$',    # Time like "5 PM"
            r'^(open|closed|opens|closes)(\s|$)',  # Status words
            r'^(monday|tuesday|wednesday|thursday|friday|saturday|sunday)',  # Days
            r'^(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)',  # Months
            r'^\$',  # Price
            r'^(website|directions|call|hours)$',  # Button text
            r'^(\d+\s*(miles?|km|feet?|ft)?)$',  # Distance
            r'^\d+(\.\d+)?\s*stars?$',  # Rating text
            r'^\(\d+\)$',  # Review count like "(145)"
            r'^[\d\.\-\(\)\s]+$',  # Only numbers/punctuation (phone, ratings)
        ]
        
        text_lower = text.lower().strip()
        for pattern in invalid_patterns:
            if re.search(pattern, text_lower, re.IGNORECASE):
                return False
        
        # Must contain at least one letter
        if not re.search(r'[a-zA-Z]', text):
            return False
            
        return True


class CompactListingExtractor(BusinessExtractor):
    """Extractor for compact listings that require clicking to see details (e.g., barber shops)"""
    
    def can_handle(self, element) -> bool:
        """Check if this is a compact listing that requires click-through"""
        try:
            # Check for action buttons with data-value attributes (stable indicators)
            action_buttons = element.find_elements(By.CSS_SELECTOR, "a[data-value], button[data-value]")
            
            # Look specifically for Website and Directions buttons
            has_website_button = False
            has_directions_button = False
            
            for button in action_buttons:
                data_value = button.get_attribute("data-value")
                if data_value == "Website":
                    has_website_button = True
                if data_value == "Directions":
                    has_directions_button = True
            
            # Standard listing has visible Website or Directions buttons
            if has_website_button or has_directions_button:
                print(f"    🔍 CompactListingExtractor: Found action buttons (Website: {has_website_button}, Directions: {has_directions_button}) - NOT COMPACT")
                return False
            
            # Check if it's a valid business listing (has business link and name)
            business_links = element.find_elements(By.CSS_SELECTOR, "a[href*='/maps/place/']")
            
            # Look for business name indicators
            has_business_name = False
            name_selectors = [
                "a[href*='/maps/place/'][aria-label]",
                "div.qBF1Pd",
                "[role='heading']",
                "h1, h2, h3, h4"
            ]
            
            for selector in name_selectors:
                try:
                    name_elem = element.find_element(By.CSS_SELECTOR, selector)
                    if name_elem and name_elem.text.strip():
                        has_business_name = True
                        break
                except:
                    continue
            
            # It's a compact listing if:
            # 1. Has business link (valid business)
            # 2. Has business name
            # 3. NO visible Website/Directions buttons
            if business_links and has_business_name:
                print(f"    🔍 CompactListingExtractor: Business listing without action buttons = COMPACT LISTING")
                return True
            else:
                print(f"    🔍 CompactListingExtractor: Not a valid compact listing (links: {bool(business_links)}, name: {has_business_name})")
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
            time.sleep(3)  # Give more time for expanded view to load
            
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
            
            # Method 2: Look for website icon/link in the info section
            if not website_url:
                try:
                    # Look for links with globe/website icon near them
                    website_links = driver.find_elements(By.CSS_SELECTOR, "a[href*='://']")
                    for link in website_links:
                        href = link.get_attribute("href")
                        # Check if it's an external website (not Google, social media, etc.)
                        if href and not any(domain in href.lower() for domain in 
                            ['google.com', 'maps.google', 'youtube.com', 'facebook.com', 
                             'instagram.com', 'twitter.com', 'yelp.com', 'tripadvisor']):
                            # Additional check: see if link text or nearby text indicates it's a website
                            link_text = link.text.strip().lower()
                            aria_label = link.get_attribute("aria-label") or ""
                            
                            # Check if this looks like the business website
                            if ('website' in aria_label.lower() or 
                                'website' in link_text or
                                link_text.endswith('.com') or 
                                link_text.endswith('.net') or
                                link_text.endswith('.org') or
                                (len(link_text) > 0 and '.' in link_text)):
                                website_url = href
                                print(f"    ✅ Found website via external link: {website_url}")
                                break
                except:
                    pass
            
            # Method 3: Look for website in the information panel (sometimes shown as plain text)
            if not website_url:
                try:
                    # Look for elements that might contain website info
                    info_elements = driver.find_elements(By.CSS_SELECTOR, "div[role='region'] span, div[aria-label] span")
                    domain_pattern = re.compile(r'(?:https?://)?(?:www\.)?([a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*\.[a-zA-Z]{2,})')
                    
                    for elem in info_elements:
                        text = elem.text.strip()
                        if text:
                            match = domain_pattern.search(text)
                            if match:
                                domain = match.group(0)
                                if not domain.startswith('http'):
                                    domain = f"https://{domain}"
                                # Verify it's not a social media or review site
                                if not any(social in domain.lower() for social in 
                                    ['facebook', 'instagram', 'twitter', 'youtube', 'yelp', 'tripadvisor']):
                                    website_url = domain
                                    print(f"    ✅ Found website via text content: {website_url}")
                                    break
                except:
                    pass
            
            # Method 4: Check for website in link elements with specific patterns
            if not website_url:
                try:
                    # Sometimes the website is in a link that opens in a new tab
                    links_with_target = driver.find_elements(By.CSS_SELECTOR, "a[target='_blank']")
                    for link in links_with_target:
                        href = link.get_attribute("href")
                        if href and 'http' in href and not any(domain in href.lower() for domain in 
                            ['google', 'facebook', 'instagram', 'twitter', 'youtube']):
                            # Check if the link text suggests it's a website
                            parent_text = link.find_element(By.XPATH, "..").text.lower()
                            if 'website' in parent_text or 'site' in parent_text:
                                website_url = href
                                print(f"    ✅ Found website via target=_blank link: {website_url}")
                                break
                except:
                    pass
            
            # Navigate back to the list
            print(f"    🔙 Navigating back to search results...")
            driver.back()
            time.sleep(2)  # Wait for page to reload
            
            # Verify we're back at the search results using stable selector
            try:
                WebDriverWait(driver, 5).until(
                    EC.presence_of_element_located((By.CSS_SELECTOR, "[role='feed'], [role='main'], [role='article']"))
                )
            except:
                print(f"    ⚠️ Timeout waiting for search results, but continuing...")
            
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
        # Test each extractor to find the right one
        for extractor in self.extractors:
            if extractor.can_handle(element):
                extractor_name = type(extractor).__name__
                print(f"    🔍 Using {extractor_name}")
                print(f"    {'─'*40}")
                return extractor.extract(element, self.driver)
        
        # Fallback to StandardListingExtractor if no extractor matches
        print(f"    🔍 No specific extractor matched, using StandardListingExtractor as fallback")
        print(f"    {'─'*40}")
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