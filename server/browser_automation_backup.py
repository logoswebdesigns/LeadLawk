#!/usr/bin/env python3
"""
Enhanced Browser Automation - Properly iterates through Google Maps results
"""

import time
import os
import platform
import re
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.desired_capabilities import DesiredCapabilities
from selenium.common.exceptions import TimeoutException, NoSuchElementException, StaleElementReferenceException
from selenium.webdriver.common.action_chains import ActionChains
from business_extractor import extract_business_details


def save_lead_to_database(business_details, job_id=None):
    """Immediately save a lead to the database as it's found"""
    try:
        from database import SessionLocal
        from models import Lead, LeadStatus
        from datetime import datetime
        
        db = SessionLocal()
        try:
            # Create the lead record
            lead = Lead(
                business_name=business_details.get('name', 'Unknown Business'),
                industry=business_details.get('industry', 'Unknown'),
                rating=float(business_details.get('rating', 0.0)),
                review_count=int(business_details.get('reviews', 0)),
                website_url=business_details.get('website'),
                has_website=business_details.get('has_website', False),
                phone=business_details.get('phone') or 'No phone',
                profile_url=business_details.get('url'),  # Google Maps URL
                location=business_details.get('location', 'Unknown'),
                status=LeadStatus.NEW,
                has_recent_reviews=business_details.get('has_recent_reviews', True),
                screenshot_path=business_details.get('screenshot_filename')
            )
            
            db.add(lead)
            db.commit()
            
            print(f"    💾 Saved lead to database: {lead.business_name} (ID: {lead.id})")
            return lead.id
            
        except Exception as e:
            print(f"    ❌ Failed to save lead to database: {e}")
            db.rollback()
            return None
        finally:
            db.close()
            
    except Exception as e:
        print(f"    ❌ Database connection error: {e}")
        return None


class BrowserAutomation:
    def __init__(self, use_profile=False, headless=False, job_id=None):
        """Initialize enhanced browser automation with better scrolling and extraction"""
        self.use_profile = use_profile
        self.headless = headless
        self.driver = None
        self.wait = None
        self.job_id = job_id
        self._cancelled = False
        self._closed = False
        self.screenshot_count = 0
        self.setup_browser()
    
    def is_cancelled(self):
        """Check if this job has been cancelled"""
        if not self.job_id:
            return False
        
        # Import here to avoid circular imports
        from main import jobs, job_lock
        
        with job_lock:
            if self.job_id in jobs:
                return jobs[self.job_id]["status"] == "cancelled"
        return False
    
    def get_chrome_profile_path(self):
        """Get the Chrome profile path for current OS"""
        system = platform.system()
        home = os.path.expanduser("~")
        
        if system == "Darwin":  # macOS
            return os.path.join(home, "Library", "Application Support", "Google", "Chrome")
        elif system == "Linux":
            return os.path.join(home, ".config", "google-chrome")
        elif system == "Windows":
            return os.path.join(home, "AppData", "Local", "Google", "Chrome", "User Data")
        return None
    
    def setup_browser(self):
        """Setup Chrome browser with RemoteWebDriver for containerized Selenium"""
        print("🚀 Setting up Chrome browser...")
        
        chrome_options = Options()
        
        # Check if running in Docker (use RemoteWebDriver)
        if os.environ.get('USE_DOCKER'):
            selenium_hub_url = os.environ.get('SELENIUM_HUB_URL', 'http://selenium-chrome:4444/wd/hub')
            print(f"🐳 Using Remote WebDriver at: {selenium_hub_url}")
            
            # Configure Chrome options for remote
            if self.headless:
                chrome_options.add_argument("--headless=new")  # Use new headless mode
                print("👻 Running in headless mode")
            else:
                print("👀 Running in visible mode")
            
            # Options for containerized Chrome
            chrome_options.add_argument("--no-sandbox")
            chrome_options.add_argument("--disable-dev-shm-usage")
            chrome_options.add_argument("--disable-gpu")
            chrome_options.add_argument("--window-size=1920,1080")
            chrome_options.add_argument("--disable-blink-features=AutomationControlled")
            chrome_options.add_experimental_option("excludeSwitches", ["enable-automation"])
            chrome_options.add_experimental_option('useAutomationExtension', False)
            
            try:
                self.driver = webdriver.Remote(
                    command_executor=selenium_hub_url,
                    options=chrome_options
                )
                self.wait = WebDriverWait(self.driver, 10)
                print("✅ Remote browser initialized successfully!")
            except Exception as e:
                print(f"❌ Failed to initialize Remote Chrome: {e}")
                raise
                
        else:
            # Local development - fallback to direct Chrome
            print("💻 Using local Chrome for development")
            
            # Find Chrome binary for local development
            chrome_paths = [
                "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
                "/Applications/Chrome.app/Contents/MacOS/Chrome",
                "/Applications/Chromium.app/Contents/MacOS/Chromium",
            ]
            
            for path in chrome_paths:
                if os.path.exists(path):
                    chrome_options.binary_location = path
                    print(f"✅ Found Chrome at: {path}")
                    break
            
            # Use existing profile if requested
            if self.use_profile:
                profile_path = self.get_chrome_profile_path()
                if profile_path and os.path.exists(profile_path):
                    print(f"✅ Using your Chrome profile from: {profile_path}")
                    chrome_options.add_argument(f"--user-data-dir={profile_path}")
                    chrome_options.add_argument("--profile-directory=Default")
            
            if self.headless:
                chrome_options.add_argument("--headless=new")
                chrome_options.add_argument("--window-size=1920,1080")
                print("👻 Running in headless mode")
            else:
                chrome_options.add_argument("--start-maximized")
                print("👀 Running in visible mode")
            
            # Options for better compatibility
            chrome_options.add_argument("--no-sandbox")
            chrome_options.add_argument("--disable-dev-shm-usage")
            chrome_options.add_argument("--disable-blink-features=AutomationControlled")
            chrome_options.add_experimental_option("excludeSwitches", ["enable-automation"])
            chrome_options.add_experimental_option('useAutomationExtension', False)
            
            try:
                from webdriver_manager.chrome import ChromeDriverManager
                from selenium.webdriver.chrome.service import Service
                
                service = Service(ChromeDriverManager().install())
                self.driver = webdriver.Chrome(service=service, options=chrome_options)
                self.wait = WebDriverWait(self.driver, 10)
                print("✅ Local browser initialized successfully!")
            except Exception as e:
                print(f"❌ Failed to initialize local Chrome: {e}")
                raise
    
    def search_google_maps(self, query, limit=20, min_rating=0.0, min_reviews=0, requires_website=None, recent_review_months=None, min_photos=None, min_description_length=None, enable_click_through=True):
        """Enhanced Google Maps search with proper iteration and scrolling
        
        Args:
            requires_website: None = any, False = no website required, True = website required
            enable_click_through: If True, will click into compact listings to check for websites
            recent_review_months: None = any, int = must have reviews within X months
            min_photos: None = any, int = minimum number of photos required
            min_description_length: None = any, int = minimum description character length
        """
        print(f"\n🚀 ENHANCED BROWSER AUTOMATION - search_google_maps called!")
        print(f"   Query: {query}, Limit: {limit}, Recent Review Months: {recent_review_months}")
        
        results = []
        processed_names = set()  # Track processed businesses to avoid duplicates
        evaluated_businesses = set()  # Track ALL businesses we've evaluated (passed or failed)
        
        # Log search criteria with explicit parameter validation
        print(f"\n🎯 Search Criteria:")
        print(f"   Query: {query}")
        print(f"   Limit: {limit} businesses")
        print(f"   Min Rating: {min_rating}")
        print(f"   Min Reviews: {min_reviews}")
        
        # Recent Review Activity Filter - EXPLICIT validation and logging
        print(f"🔧 DEBUG: recent_review_months = {recent_review_months} (type: {type(recent_review_months)})")
        print(f"🔧 DEBUG: recent_review_months is None = {recent_review_months is None}")
        print(f"🔧 DEBUG: recent_review_months == None = {recent_review_months == None}")
        
        # Force explicit None check to prevent any caching issues
        if recent_review_months is not None and recent_review_months != "":
            print(f"   Recent Reviews: Within {recent_review_months} months (requires profile access)")
            apply_recent_review_filter = True
        else:
            print(f"   Recent Reviews: N/A (no recency filter - accepting all review dates)")
            apply_recent_review_filter = False
            # Explicitly set to None to prevent any cached values
            recent_review_months = None
        
        # Website Filter
        if requires_website is None:
            print(f"   Website Filter: ANY (all businesses)")
        elif requires_website == False:
            print(f"   Website Filter: NO WEBSITE ONLY (ideal prospects for web design)")
        elif requires_website == True:
            print(f"   Website Filter: MUST HAVE WEBSITE")
        
        # This section moved to the main search criteria block above
            
        # Photo Count Filter (Digital Presence)
        if min_photos is not None:
            print(f"   Min Photos: {min_photos}+ photos (digital presence)")
        else:
            print(f"   Min Photos: N/A (no photo requirement)")
        
        # Business Description Quality Filter
        if min_description_length is not None:
            print(f"   Min Description: {min_description_length}+ characters (quality indicator)")
        else:
            print(f"   Min Description: N/A (no description requirement)")
        
        # Debug: Show raw parameter values
        print(f"\n🔧 Debug - Raw Parameters:")
        print(f"   recent_review_months = {recent_review_months} (type: {type(recent_review_months)})")
        print(f"   min_photos = {min_photos} (type: {type(min_photos)})")  
        print(f"   min_description_length = {min_description_length} (type: {type(min_description_length)})")
        print(f"   requires_website = {requires_website} (type: {type(requires_website)})")
        
        # Additional debug logging with explicit filter status
        print(f"\n🔬 Filter Check:")
        print(f"   Will apply recent review filter: {apply_recent_review_filter}")
        if apply_recent_review_filter:
            print(f"   Recent review threshold: {recent_review_months} months")
        else:
            print(f"   Recent review filtering: DISABLED (accepting all review dates)")
        
        try:
            # Navigate to Google Maps
            print(f"\n📍 Opening Google Maps...")
            self.driver.get("https://www.google.com/maps")
            time.sleep(2)
            
            # Perform search
            print(f"🔍 Searching for: {query}")
            search_box = self.wait.until(
                EC.presence_of_element_located((By.ID, "searchboxinput"))
            )
            search_box.clear()
            search_box.send_keys(query)
            search_box.send_keys(Keys.RETURN)
            
            # Wait for results to load
            time.sleep(3)
            
            # Check if we have list results
            try:
                results_panel = self.wait.until(
                    EC.presence_of_element_located((By.CSS_SELECTOR, "[role='feed']"))
                )
                print("✅ Found results panel")
                
                # Take screenshot of initial search area
                self._take_screenshot("initial_search_area")
                
            except:
                print("❌ No results found")
                return results
            
            attempts = 0
            max_attempts = 5  # Maximum scroll attempts
            expansions_tried = 0
            max_expansions = 3  # Maximum area expansions
            
            while len(results) < limit and attempts < max_attempts:
                # Check for cancellation
                if self.is_cancelled():
                    print("❌ Job cancelled by user")
                    self.close()  # Close browser session immediately
                    return results
                
                attempts += 1
                print(f"\n📜 Scroll attempt {attempts}/{max_attempts}")
                
                # Get all business elements
                business_elements = self.driver.find_elements(
                    By.CSS_SELECTOR, 
                    "[role='feed'] > div > div[jsaction]"
                )
                
                print(f"  Found {len(business_elements)} businesses in view")
                
                # Process each business
                for idx, business in enumerate(business_elements):
                    if len(results) >= limit:
                        break
                    
                    # Check for cancellation in inner loop too
                    if self.is_cancelled():
                        print("❌ Job cancelled by user")
                        self.close()  # Close browser session immediately
                        return results
                    
                    try:
                        print(f"    🔍 About to extract from business element...")
                        
                        # Extract ALL info directly from the list view - with click-through for compact listings
                        details = extract_business_details(business, self.driver, enable_click_through=enable_click_through)
                        
                        print(f"    📋 Extracted details: {details}")
                        
                        if not details or not details.get('name'):
                            print(f"    ❌ No valid details extracted, skipping")
                            continue
                            
                        name = details['name']
                        
                        # Skip if already evaluated (either passed or failed in previous zoom levels)
                        # But allow re-processing if the business is in DB but missing screenshot
                        if name in evaluated_businesses:
                            # Check if this business is in database but missing screenshot
                            try:
                                from database import SessionLocal
                                from models import Lead
                                db = SessionLocal()
                                existing_lead = db.query(Lead).filter(Lead.business_name == name).first()
                                db.close()
                                
                                if existing_lead and not existing_lead.screenshot_path:
                                    print(f"    🔄 Re-processing {name} - found in DB but missing screenshot")
                                    # Don't skip, allow screenshot capture
                                else:
                                    print(f"    ⏭️ Skipping {name} - already evaluated in previous area")
                                    continue
                            except Exception as e:
                                print(f"    ⚠️ Error checking DB for {name}: {e}")
                                print(f"    ⏭️ Skipping {name} - already evaluated in previous area")
                                continue
                        
                        # Mark as evaluated (regardless of whether it passes filters)
                        evaluated_businesses.add(name)
                        
                        print(f"\n  [{len(results)+1}/{limit}] Processing: {name}")
                        
                        if details:
                            # Apply filters
                            rating_val = float(details.get('rating', 0))
                            reviews_val = int(details.get('reviews', 0))
                            has_website = details.get('has_website', False)
                            photo_count = int(details.get('photo_count', 0))
                            desc_length = int(details.get('description_length', 0))
                            
                            # Apply basic rating and reviews filters
                            if rating_val >= min_rating and reviews_val >= min_reviews:
                                # Apply website filter
                                website_filter_passed = True
                                if requires_website is not None:
                                    if requires_website == False and has_website:
                                        website_filter_passed = False
                                        print(f"    ⏭️ Skipped: Has website (filter: no website)")
                                    elif requires_website == True and not has_website:
                                        website_filter_passed = False
                                        print(f"    ⏭️ Skipped: No website (filter: has website)")
                                
                                # Apply photo count filter
                                photo_filter_passed = True
                                if min_photos is not None and photo_count < min_photos:
                                    photo_filter_passed = False
                                    print(f"    ⏭️ Skipped: Too few photos ({photo_count} < {min_photos})")
                                
                                # Apply description length filter (fast - already extracted)
                                description_filter_passed = True
                                if min_description_length is not None and desc_length < min_description_length:
                                    description_filter_passed = False
                                    print(f"    ⏭️ Skipped: Description too short ({desc_length} < {min_description_length} chars)")
                                
                                # Only proceed with expensive recent review check if all fast filters pass
                                if website_filter_passed and photo_filter_passed and description_filter_passed:
                                    # Apply recent review filter (expensive - requires profile click)
                                    recent_review_filter_passed = True
                                    if apply_recent_review_filter and recent_review_months is not None:
                                        print(f"    🔍 Checking recent reviews (within {recent_review_months} months)...")
                                        has_recent_reviews, last_review_date = self._check_recent_reviews_profile(business, recent_review_months)
                                        # Store the last review date and recent review status in details
                                        details['last_review_date'] = last_review_date
                                        details['has_recent_reviews'] = has_recent_reviews
                                        if not has_recent_reviews:
                                            recent_review_filter_passed = False
                                            print(f"    ⏭️ Skipped: No recent reviews within {recent_review_months} months")
                                        else:
                                            print(f"    ✅ Recent review check passed")
                                    else:
                                        print(f"    ⏭️ Skipping recent review check (no filter applied)")
                                        # Set default values when not checking
                                        details['last_review_date'] = None
                                        details['has_recent_reviews'] = True  # Default to true when not filtering
                                    
                                    if recent_review_filter_passed:
                                        # Check if this lead already exists in database
                                        existing_lead = None
                                        try:
                                            from database import SessionLocal
                                            from models import Lead
                                            db = SessionLocal()
                                            existing_lead = db.query(Lead).filter(Lead.business_name == name).first()
                                            db.close()
                                        except Exception as e:
                                            print(f"    ⚠️ Error checking existing lead for {name}: {e}")
                                        
                                        # If lead doesn't exist, add to results and process normally
                                        if not existing_lead:
                                            processed_names.add(name)
                                            results.append(details)
                                            # Set industry and location based on query if available
                                            details['industry'] = self._extract_industry_from_query(query)
                                            details['location'] = self._extract_location_from_query(query)
                                        
                                        # Always take screenshot if lead is new OR existing lead has no screenshot
                                        take_screenshot = not existing_lead or (existing_lead and not existing_lead.screenshot_path)
                                        print(f"    🔍 Screenshot decision: existing_lead={existing_lead is not None}, take_screenshot={take_screenshot}")
                                        
                                        
                                        if take_screenshot:
                                            print(f"    📸 About to take business screenshot for {'new' if not existing_lead else 'existing'} lead: {details['name']}")
                                            screenshot_filename = self._take_business_screenshot(details['name'], business)
                                            if screenshot_filename:
                                                details['screenshot_filename'] = screenshot_filename
                                                print(f"    ✅ Screenshot filename captured: {screenshot_filename}")
                                            else:
                                                print(f"    ❌ No screenshot filename returned for {details['name']}")
                                        
                                        # Save to database (create new or update existing)
                                        if not existing_lead:
                                            lead_id = save_lead_to_database(details, job_id=self.job_id)
                                            website_status = "🌐 Has website" if has_website else "❌ No website"
                                            photo_status = f"📸 {photo_count} photos"
                                            desc_status = f"📝 {desc_length}ch desc" if desc_length > 0 else "📝 No desc"
                                            print(f"    ✅ Added: {details['name']} - ⭐ {rating_val} ({reviews_val} reviews) - {website_status} - {photo_status} - {desc_status}")
                                        else:
                                            # Update existing lead with screenshot
                                            if take_screenshot and screenshot_filename:
                                                try:
                                                    db = SessionLocal()
                                                    existing_lead.screenshot_path = screenshot_filename
                                                    db.commit()
                                                    db.close()
                                                    print(f"    ✅ Updated existing lead {details['name']} with screenshot: {screenshot_filename}")
                                                except Exception as e:
                                                    print(f"    ❌ Error updating lead {details['name']} with screenshot: {e}")
                                            else:
                                                print(f"    ⏭️ Existing lead {details['name']} already has screenshot or screenshot capture failed")
                                else:
                                    print(f"    ⏭️ Skipped: Failed fast filters (website/photos/description)")
                            else:
                                print(f"    ⏭️ Skipped: Below threshold (⭐ {rating_val}, {reviews_val} reviews)")
                    
                    except StaleElementReferenceException:
                        print(f"    ⚠️ Element became stale, continuing...")
                        continue
                    except Exception as e:
                        print(f"    ❌ Error processing business: {e}")
                        continue
                
                # Scroll to load more results if needed
                if len(results) < limit:
                    print(f"\n  📜 Scrolling for more results... (have {len(results)}/{limit})")
                    self._scroll_results_panel()
                    time.sleep(2)  # Wait for new results to load
                
                # If we've reached max attempts and still need more results, try expanding
                if len(results) < limit and attempts >= max_attempts - 1 and expansions_tried < max_expansions:
                    print(f"\n🔍 Only found {len(results)}/{limit} leads in current area")
                    if self._expand_search_area(expansions_tried + 1, evaluated_businesses):
                        expansions_tried += 1
                        attempts = 0  # Reset scroll attempts for new area
                        print(f"🗺️ Search area expanded ({expansions_tried}/{max_expansions}), restarting search...")
                        continue  # Continue the while loop with new area
                    else:
                        print(f"❌ Could not expand search area, stopping with {len(results)} results")
                        break  # Exit the while loop if we can't expand
            
            print(f"\n✅ Extraction complete: Found {len(results)} qualifying leads")
            
            # Take final screenshot showing completed search area
            self._take_screenshot("final_search_complete")
            
        except Exception as e:
            print(f"❌ Search failed: {e}")
        
        return results
    
    def _extract_business_from_list(self, element):
        """Extract all business information directly from the list element"""
        details = {}
        
        try:
            print(f"    🔍 Extracting from list element...")
            # Business name - from the fontHeadlineSmall div
            try:
                name_elem = element.find_element(By.CSS_SELECTOR, ".qBF1Pd.fontHeadlineSmall")
                details['name'] = name_elem.text.strip()
            except:
                # Fallback: try getting from aria-label
                try:
                    link_elem = element.find_element(By.CSS_SELECTOR, "a.hfpxzc")
                    details['name'] = link_elem.get_attribute("aria-label")
                except:
                    details['name'] = "Unknown Business"
            
            # Rating and Reviews from the ZkP5Je span with aria-label
            try:
                rating_container = element.find_element(By.CSS_SELECTOR, "span.ZkP5Je[aria-label]")
                aria_label = rating_container.get_attribute("aria-label")
                print(f"    📊 Found rating container with aria-label: {aria_label}")
                
                # Parse "4.8 stars 541 Reviews" format exactly
                if aria_label:
                    # Extract rating from "4.8 stars"
                    rating_match = re.search(r'^([\d\.]+)\s+stars?', aria_label)
                    if rating_match:
                        details['rating'] = rating_match.group(1)
                    else:
                        details['rating'] = "0"
                    
                    # Extract review count from "541 Reviews"
                    review_match = re.search(r'(\d[\d,]*)\s+Reviews?', aria_label)
                    if review_match:
                        details['reviews'] = review_match.group(1).replace(',', '')
                        print(f"    ✅ Found reviews: {details['reviews']} from aria-label: {aria_label}")
                    else:
                        details['reviews'] = "0"
                        print(f"    ⚠️ No reviews found in aria-label: {aria_label}")
                else:
                    details['rating'] = "0"
                    details['reviews'] = "0"
                    
            except:
                # Fallback: try to get review count from UY7F9 span
                try:
                    review_span = element.find_element(By.CSS_SELECTOR, "span.UY7F9")
                    review_text = review_span.text or ""
                    
                    # Extract number from "(541)" format
                    match = re.search(r'\((\d[\d,]*)\)', review_text)
                    if match:
                        details['reviews'] = match.group(1).replace(',', '')
                        print(f"    ✅ Found reviews: {details['reviews']} from UY7F9 span")
                    else:
                        details['reviews'] = "0"
                        
                    # Try to get rating from MW4etd span
                    try:
                        rating_span = element.find_element(By.CSS_SELECTOR, "span.MW4etd")
                        details['rating'] = rating_span.text or "0"
                    except:
                        details['rating'] = "0"
                        
                except:
                    details['rating'] = "0"
                    details['reviews'] = "0"
            
            # Phone number - from UsdlK span
            try:
                phone_elem = element.find_element(By.CSS_SELECTOR, "span.UsdlK")
                details['phone'] = phone_elem.text.strip()
            except:
                details['phone'] = None
            
            # Website - check if there's a website link
            try:
                website_elem = element.find_element(By.CSS_SELECTOR, "a[data-value='Website']")
                details['website'] = website_elem.get_attribute("href")
                details['has_website'] = True
            except:
                details['website'] = None
                details['has_website'] = False
                
            # Current URL - get the main business link
            try:
                link_elem = element.find_element(By.CSS_SELECTOR, "a.hfpxzc")
                details['url'] = link_elem.get_attribute("href")
            except:
                details['url'] = self.driver.current_url
            
            # Photo count - look for photo indicators
            try:
                # Try to find photo count from the photo section
                photo_elements = element.find_elements(By.CSS_SELECTOR, "img[src*='googleusercontent']")
                details['photo_count'] = len(photo_elements)
                print(f"    📸 Found {len(photo_elements)} photos")
            except:
                details['photo_count'] = 0
                print(f"    📸 No photos detected")
            
            # Business description - get any description text
            try:
                # Look for description or snippet text
                desc_elem = element.find_element(By.CSS_SELECTOR, ".lI9IFe, .PZPZlf, .fontBodyMedium")
                details['description'] = desc_elem.text.strip()[:200]  # First 200 chars
                details['description_length'] = len(details['description'])
                print(f"    📝 Description: {details['description_length']} chars")
            except:
                details['description'] = ""
                details['description_length'] = 0
                print(f"    📝 No description found")
            
            # Initialize recent review fields - will be set properly during filtering if needed
            details['has_recent_reviews'] = True  # Default true, will be validated if recent_review_months filter is applied
            details['last_review_date'] = None  # Will be set if we check review dates
            
            return details
            
        except Exception as e:
            print(f"    ⚠️ Error extracting from list element: {e}")
            return None
    
    
    def _scroll_results_panel(self):
        """Scroll the results panel to load more businesses"""
        try:
            # Find the scrollable element
            scrollable = self.driver.find_element(
                By.CSS_SELECTOR,
                "[role='feed']"
            )
            
            # Scroll down
            self.driver.execute_script(
                "arguments[0].scrollTop = arguments[0].scrollHeight",
                scrollable
            )
            
        except Exception as e:
            print(f"    ⚠️ Scroll failed: {e}")
    
    def _take_screenshot(self, description="screenshot", log_to_job=True):
        """Take a screenshot and save it with job ID and description"""
        import os
        import time
        
        try:
            if not self.driver:
                return None
            
            # Don't cleanup business screenshots - only cleanup non-business screenshots
            if not description.startswith("business_"):
                # Clean up old non-business screenshots for this job (keep max 3)
                self._cleanup_old_screenshots(exclude_business=True)
            
            self.screenshot_count += 1
            timestamp = time.strftime("%H%M%S")
            filename = f"job_{self.job_id}_{self.screenshot_count:02d}_{timestamp}_{description}.png"
            filepath = f"/app/screenshots/{filename}"
            
            # Take the screenshot
            success = self.driver.save_screenshot(filepath)
            
            if success:
                # Wait briefly for file system to complete write, then verify
                
                # Retry verification up to 3 times with increasing delays
                for attempt in range(3):
                    time.sleep(0.2 * (attempt + 1))  # 0.2s, 0.4s, 0.6s delays
                    
                    if os.path.exists(filepath) and os.path.getsize(filepath) > 0:
                        print(f"    📸 Screenshot saved and verified: {filename} (attempt {attempt + 1})")
                        if log_to_job and self.job_id:
                            # Import here to avoid circular imports
                            from main import add_job_log
                            add_job_log(self.job_id, f"📸 Screenshot captured: {description} ({filename})")
                        return filename
                    
                    if attempt < 2:  # Don't log on final attempt (will be handled below)
                        print(f"    ⏳ Screenshot file not ready yet, retrying... (attempt {attempt + 1}/3)")
                
                print(f"    ❌ Screenshot file not found or empty after save_screenshot returned True: {filename}")
                return None
            else:
                print(f"    ❌ Failed to save screenshot: {filename}")
                return None
                
        except Exception as e:
            print(f"    ❌ Screenshot error: {e}")
            return None
    
    def _cleanup_old_screenshots(self, max_screenshots=3, exclude_business=False):
        """Keep only the most recent screenshots for this job
        
        Args:
            max_screenshots: Maximum number of non-business screenshots to keep
            exclude_business: If True, don't delete business screenshots
        """
        try:
            import os
            from pathlib import Path
            
            screenshots_dir = Path("/app/screenshots")
            if not screenshots_dir.exists():
                return
            
            # Find all screenshots for this job
            job_screenshots = []
            for filename in os.listdir(screenshots_dir):
                if filename.startswith(f"job_{self.job_id}_") and filename.endswith(".png"):
                    # Skip business screenshots if exclude_business is True
                    if exclude_business and "_business_" in filename:
                        continue
                    
                    filepath = screenshots_dir / filename
                    # Get file modification time
                    mtime = os.path.getmtime(filepath)
                    job_screenshots.append((filepath, mtime, filename))
            
            # Sort by modification time (newest first)
            job_screenshots.sort(key=lambda x: x[1], reverse=True)
            
            # Remove old screenshots if we have more than max_screenshots
            if len(job_screenshots) > max_screenshots:
                screenshots_to_remove = job_screenshots[max_screenshots:]
                for filepath, _, filename in screenshots_to_remove:
                    try:
                        os.remove(filepath)
                        print(f"    🗑️ Removed old screenshot: {filename}")
                    except Exception as e:
                        print(f"    ⚠️ Error removing screenshot {filename}: {e}")
                        
        except Exception as e:
            print(f"    ⚠️ Error in screenshot cleanup: {e}")
    
    def _expand_search_area(self, expansion_number, evaluated_businesses):
        """Expand the search area by zooming out and clicking 'Search this area'"""
        try:
            print(f"\n🗺️ Attempting search area expansion #{expansion_number}")
            print(f"    📊 Already evaluated {len(evaluated_businesses)} businesses")
            
            # Step 1: Zoom out AGGRESSIVELY to expand the visible area
            print(f"    🔍 Aggressively zooming out map (expansion #{expansion_number})...")
            try:
                # Try multiple zoom out methods with MUCH more aggressive zooming
                zoom_out_successful = False
                
                # Calculate very conservative zoom steps for minimal radius increases per expansion
                # Extremely reduced to prevent over-expansion - stay local
                if expansion_number == 1:
                    zoom_steps = 1  # Very small initial expansion
                elif expansion_number == 2:
                    zoom_steps = 1  # Very small additional expansion 
                elif expansion_number >= 3:
                    zoom_steps = 1  # Very small additional expansion
                
                print(f"    📏 Using {zoom_steps} zoom steps for controlled expansion #{expansion_number} (~20-50 mile increment)")
                
                # Method 1: Use keyboard shortcut (most reliable) - AGGRESSIVE
                try:
                    from selenium.webdriver.common.action_chains import ActionChains
                    actions = ActionChains(self.driver)
                    # Focus on the map and use minus key to zoom out MANY times
                    map_element = self.driver.find_element(By.ID, "map")
                    actions.click(map_element)
                    
                    # Zoom out very conservatively - just 1 step total, not per loop
                    actions.send_keys('-')
                    time.sleep(0.5)  # Single conservative zoom out step
                    actions.perform()
                    
                    zoom_out_successful = True
                    print(f"    ✅ Aggressively zoomed out {zoom_steps} steps using keyboard")
                except:
                    pass
                
                # Method 2: Look for zoom out button
                if not zoom_out_successful:
                    try:
                        zoom_out_selectors = [
                            "button[aria-label*='Zoom out']",
                            "button[title*='Zoom out']",
                            ".widget-zoom-out",
                            "div[data-value='zoom_out']"
                        ]
                        
                        for selector in zoom_out_selectors:
                            try:
                                zoom_button = self.driver.find_element(By.CSS_SELECTOR, selector)
                                # Click the zoom out button just once for conservative expansion
                                self.driver.execute_script("arguments[0].click();", zoom_button)
                                time.sleep(0.5)  # Single conservative zoom out click
                                zoom_out_successful = True
                                print(f"    ✅ Aggressively zoomed out {zoom_steps} times using button: {selector}")
                                break
                            except:
                                continue
                    except:
                        pass
                
                # Method 3: JavaScript zoom out (fallback)
                if not zoom_out_successful:
                    try:
                        # Conservative mouse wheel scroll for moderate zoom out
                        self.driver.execute_script(f"""
                            var mapElement = document.getElementById('map');
                            if (mapElement) {{
                                // Dispatch wheel events for moderate zoom out (~20 mile increments)
                                for (let i = 0; i < {zoom_steps}; i++) {{
                                    var event = new WheelEvent('wheel', {{
                                        deltaY: 40,  // Further reduced deltaY for minimal zoom out
                                        bubbles: true,
                                        cancelable: true
                                    }});
                                    mapElement.dispatchEvent(event);
                                    // Small delay between events
                                    if (i < {zoom_steps - 1}) {{
                                        setTimeout(function() {{}}, 150);
                                    }}
                                }}
                            }}
                        """)
                        zoom_out_successful = True
                        print(f"    ✅ Moderately zoomed out {zoom_steps} steps for ~20 mile radius expansion")
                    except:
                        pass
                
                if not zoom_out_successful:
                    print(f"    ⚠️ Could not zoom out, but continuing to look for 'Search this area' button")
                
                # Wait for map to update
                time.sleep(2)
                
                # Take screenshot after zooming out (limit to 3 total expansion screenshots)
                if expansion_number <= 3:
                    self._take_screenshot(f"expansion_{expansion_number}")
                
            except Exception as zoom_error:
                print(f"    ⚠️ Zoom out error: {zoom_error}")
            
            # Step 2: Look for and click "Search this area" button
            print(f"    🔍 Looking for 'Search this area' button...")
            search_area_button = None
            
            # Based on user's provided HTML structure
            search_area_selectors = [
                "button[aria-label='Search this area']",
                "button.NlVald.UUrkN.cDZBKc[aria-label='Search this area']",
                "button[jsaction='search.refresh']",
                "button:contains('Search this area')",
                # Fallback selectors
                "button[aria-label*='Search this area']",
                "button[class*='NlVald'][class*='UUrkN']"
            ]
            
            for selector in search_area_selectors:
                try:
                    if 'contains' in selector:
                        # Use XPath for text content search
                        xpath = "//button[contains(., 'Search this area')]"
                        search_area_button = self.driver.find_element(By.XPATH, xpath)
                    else:
                        search_area_button = self.driver.find_element(By.CSS_SELECTOR, selector)
                    print(f"    ✅ Found 'Search this area' button with: {selector}")
                    break
                except:
                    continue
            
            if search_area_button:
                # Before clicking "Search this area", modify search to be location-independent
                print(f"    🔄 Modifying search query to remove location constraints...")
                try:
                    # Clear the search box and enter a broader search term
                    search_box = self.driver.find_element(By.CSS_SELECTOR, "input[id='searchboxinput']")
                    if search_box:
                        # Extract just the industry from the original query
                        # Handle formats like: "dentist near Broken Bow, NE", "dentist in Omaha", "landscaper Omaha NE"
                        original_query = search_box.get_attribute("value")
                        if original_query:
                            industry_only = None
                            
                            # Try different patterns to extract industry
                            if " near " in original_query:
                                industry_only = original_query.split(" near ")[0].strip()
                            elif " in " in original_query:
                                industry_only = original_query.split(" in ")[0].strip()
                            else:
                                # For formats like "landscaper Omaha NE", take the first word
                                words = original_query.split()
                                if len(words) > 1:
                                    # Assume first word is the industry if there are multiple words
                                    industry_only = words[0].strip()
                                else:
                                    industry_only = original_query  # Already generic
                            
                            if industry_only and industry_only != original_query:
                                print(f"    📝 Changing query from '{original_query}' to '{industry_only}'")
                                
                                # Clear and enter new broader search
                                search_box.clear()
                                time.sleep(0.5)
                                search_box.send_keys(industry_only)
                                time.sleep(1)
                                print(f"    ✅ Search query broadened for expanded area")
                                
                                # Query modified - no additional screenshot needed
                            else:
                                print(f"    ℹ️ Query already generic or couldn't improve: {original_query}")
                        else:
                            print(f"    ⚠️ No query found in search box")
                    else:
                        print(f"    ⚠️ Could not find search input box")
                except Exception as search_mod_error:
                    print(f"    ⚠️ Could not modify search query: {search_mod_error}")
                
                # Instead of clicking button, submit the search with Enter key
                print(f"    ⌨️ Submitting search with Enter key instead of clicking button...")
                try:
                    search_box = self.driver.find_element(By.CSS_SELECTOR, "input[id='searchboxinput']")
                    if search_box:
                        # Focus on search box and press Enter
                        search_box.click()
                        time.sleep(0.5)
                        search_box.send_keys(Keys.RETURN)
                        print(f"    ✅ Search submitted with Enter key")
                    else:
                        # Fallback to clicking the button if search box not found
                        print(f"    ⚠️ Search box not found, falling back to button click")
                        self.driver.execute_script("arguments[0].click();", search_area_button)
                except Exception as enter_error:
                    print(f"    ⚠️ Enter key failed: {enter_error}, falling back to button click")
                    self.driver.execute_script("arguments[0].click();", search_area_button)
                
                # Wait for new results to load
                time.sleep(3)
                
                # Check if we have new results loading
                try:
                    self.wait.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[role='feed']")))
                    print(f"    ✅ New search results are loading...")
                    time.sleep(2)  # Additional wait for results to populate
                    
                    # Search area expanded successfully - screenshot already taken
                    
                    return True
                    
                except:
                    print(f"    ⚠️ No new results detected after area expansion")
                    return False
                    
            else:
                print(f"    ❌ Could not find 'Search this area' button")
                return False
            
        except Exception as e:
            print(f"    ❌ Search area expansion failed: {e}")
            return False
    
    def _check_recent_reviews_profile(self, business_element, months_threshold):
        """Check if business has recent reviews by clicking into the profile and return last review date"""
        try:
            from datetime import datetime, timedelta
            import re
            import time
            
            # Session check - verify driver is still valid
            try:
                self.driver.current_url  # This will throw if session is lost
            except Exception as session_error:
                print(f"        ❌ Browser session lost: {session_error}")
                return False, None
            
            # Safety check: ensure we don't have too many tabs open
            if len(self.driver.window_handles) > 5:
                print(f"        ⚠️ Too many tabs open ({len(self.driver.window_handles)}), closing extras...")
                # Close all but the first tab
                original_window = self.driver.window_handles[0]
                for handle in self.driver.window_handles[1:]:
                    try:
                        self.driver.switch_to.window(handle)
                        self.driver.close()
                    except:
                        pass
                self.driver.switch_to.window(original_window)
            
            # Get current window handle
            original_window = self.driver.current_window_handle
            
            # Find and click the business link
            try:
                business_link = business_element.find_element(By.CSS_SELECTOR, "a.hfpxzc")
                business_url = business_link.get_attribute("href")
                
                # Open in new tab to avoid losing current state
                try:
                    self.driver.execute_script("window.open(arguments[0]);", business_url)
                    # Add small delay to ensure tab creation
                    time.sleep(0.5)
                    # Find the new window handle
                    new_handles = [handle for handle in self.driver.window_handles if handle != original_window]
                    if not new_handles:
                        print(f"        ❌ Failed to create new tab")
                        return False, None
                    new_window = new_handles[0]
                    self.driver.switch_to.window(new_window)
                except Exception as tab_error:
                    print(f"        ❌ Tab creation failed: {tab_error}")
                    return False, None
                
                # Wait for profile to load
                WebDriverWait(self.driver, 10).until(
                    EC.presence_of_element_located((By.CSS_SELECTOR, "h1"))
                )
                
                print(f"        📱 Profile loaded, now clicking Reviews tab...")
                
                # Click on the Reviews tab to show all reviews with timestamps
                try:
                    # Look for Reviews tab using the specific structure provided by user
                    reviews_tab = None
                    possible_selectors = [
                        # User-provided specific structure
                        "button[role='tab'].hh2c6.G7m0Af[aria-label*='Reviews']",
                        "button[role='tab'][aria-label*='Reviews']",
                        "button.hh2c6.G7m0Af[aria-label*='Reviews']",
                        # Fallback selectors
                        "button[data-value='Reviews']",
                        "button[aria-label*='Reviews']"
                    ]
                    
                    for selector in possible_selectors:
                        try:
                            reviews_tab = self.driver.find_element(By.CSS_SELECTOR, selector)
                            print(f"        ✅ Found Reviews tab with selector: {selector}")
                            break
                        except:
                            continue
                    
                    # If CSS selectors fail, try XPath as backup
                    if not reviews_tab:
                        try:
                            xpath_selectors = [
                                "//button[@role='tab' and contains(@aria-label, 'Reviews')]",
                                "//button[contains(@aria-label, 'Reviews')]",
                                "//button[@role='tab']//div[contains(text(), 'Reviews')]/ancestor::button",
                                "//button//div[@class='Gpq6kf NlVald' and text()='Reviews']/ancestor::button"
                            ]
                            for xpath in xpath_selectors:
                                try:
                                    reviews_tab = self.driver.find_element(By.XPATH, xpath)
                                    print(f"        ✅ Found Reviews tab with XPath: {xpath}")
                                    break
                                except:
                                    continue
                        except:
                            pass
                    
                    if reviews_tab:
                        print(f"        🖱️ Found Reviews tab, clicking...")
                        self.driver.execute_script("arguments[0].click();", reviews_tab)
                        
                        # Wait for reviews to load
                        time.sleep(2)
                        
                        # Now click Sort to ensure we see the newest reviews first
                        try:
                            print(f"        🔄 Looking for Sort button...")
                            sort_button = None
                            sort_selectors = [
                                # Based on user's provided HTML structure
                                "button[aria-label='Sort reviews'][data-value='Sort']",
                                "button[data-value='Sort']",
                                ".GMtm7c.fontTitleSmall:contains('Sort')/ancestor::button",
                                "button[aria-label*='Sort']"
                            ]
                            
                            for selector in sort_selectors:
                                try:
                                    if 'contains' in selector:
                                        # Use XPath for text content search
                                        xpath = "//span[@class='GMtm7c fontTitleSmall' and text()='Sort']/ancestor::button"
                                        sort_button = self.driver.find_element(By.XPATH, xpath)
                                    else:
                                        sort_button = self.driver.find_element(By.CSS_SELECTOR, selector)
                                    print(f"        ✅ Found Sort button with selector: {selector}")
                                    break
                                except:
                                    continue
                            
                            if sort_button:
                                print(f"        🖱️ Clicking Sort button...")
                                self.driver.execute_script("arguments[0].click();", sort_button)
                                time.sleep(1)
                                
                                # Look for "Newest" option in the sort menu
                                try:
                                    print(f"        🔍 Looking for Newest option...")
                                    newest_option = None
                                    newest_selectors = [
                                        "div[role='menuitem'][aria-label*='Newest']",
                                        "div[role='menuitem']:contains('Newest')",
                                        "div[data-value='Newest']",
                                        "[aria-label*='Newest']"
                                    ]
                                    
                                    for selector in newest_selectors:
                                        try:
                                            if 'contains' in selector:
                                                # Use XPath for text content search
                                                xpath = "//div[@role='menuitem' and contains(text(), 'Newest')]"
                                                newest_option = self.driver.find_element(By.XPATH, xpath)
                                            else:
                                                newest_option = self.driver.find_element(By.CSS_SELECTOR, selector)
                                            print(f"        ✅ Found Newest option with selector: {selector}")
                                            break
                                        except:
                                            continue
                                    
                                    if newest_option:
                                        print(f"        🖱️ Clicking Newest option...")
                                        self.driver.execute_script("arguments[0].click();", newest_option)
                                        time.sleep(2)  # Wait for reviews to re-sort
                                        print(f"        ✅ Reviews sorted by Newest")
                                    else:
                                        print(f"        ⚠️ Could not find Newest option, reviews may already be sorted")
                                        
                                except Exception as newest_error:
                                    print(f"        ⚠️ Could not click Newest option: {newest_error}")
                                    
                            else:
                                print(f"        ⚠️ Could not find Sort button, reviews may already be sorted by newest")
                                
                        except Exception as sort_error:
                            print(f"        ⚠️ Could not sort reviews: {sort_error}")
                        
                    else:
                        print(f"        ⚠️ Could not find Reviews tab, looking for reviews on current page")
                        
                except Exception as e:
                    print(f"        ⚠️ Error clicking Reviews tab: {e}")
                
                # Look for review timestamps (should now be visible after clicking Reviews tab)
                has_recent_review = False
                last_review_date = None
                most_recent_months_ago = None
                try:
                    # Target the specific review timestamp selector
                    review_timestamps = self.driver.find_elements(By.CSS_SELECTOR, ".rsqaWe")
                    
                    print(f"        📅 Found {len(review_timestamps)} review timestamps to check")
                    
                    for timestamp_element in review_timestamps:
                        text = timestamp_element.text.lower().strip()
                        
                        if text and any(term in text for term in ['ago', 'week', 'month', 'day', 'year']):
                            print(f"        🕒 Found review timestamp: '{text}'")
                            
                            # Convert timestamp to months ago for comparison
                            months_ago = None
                            
                            # Parse different time formats
                            if 'day' in text and 'ago' in text:
                                if 'a day ago' in text or '1 day ago' in text:
                                    months_ago = 0
                                else:
                                    day_match = re.search(r'(\d+)\s*days?\s*ago', text)
                                    if day_match:
                                        days_ago = int(day_match.group(1))
                                        months_ago = days_ago / 30
                                        
                            elif 'week' in text and 'ago' in text:
                                if 'a week ago' in text:
                                    months_ago = 1/4
                                else:
                                    week_match = re.search(r'(\d+)\s*weeks?\s*ago', text)
                                    if week_match:
                                        weeks_ago = int(week_match.group(1))
                                        months_ago = weeks_ago / 4
                                    
                            elif 'month' in text and 'ago' in text:
                                month_match = re.search(r'(\d+)\s*months?\s*ago', text)
                                if month_match:
                                    months_ago = int(month_match.group(1))
                                elif 'a month ago' in text:
                                    months_ago = 1
                                    
                            elif 'year' in text and 'ago' in text:
                                year_match = re.search(r'(\d+)\s*years?\s*ago', text)
                                if year_match:
                                    years_ago = int(year_match.group(1))
                                    months_ago = years_ago * 12
                                elif 'a year ago' in text:
                                    months_ago = 12
                            
                            # Track the most recent review (smallest months_ago value)
                            if months_ago is not None:
                                if most_recent_months_ago is None or months_ago < most_recent_months_ago:
                                    most_recent_months_ago = months_ago
                                    # Calculate actual date
                                    last_review_date = datetime.utcnow() - timedelta(days=months_ago * 30)
                                    
                                # Check if this review meets the threshold
                                if months_ago <= months_threshold:
                                    has_recent_review = True
                                    print(f"        ✅ Recent review: {text} ({months_ago:.1f} months ago - within {months_threshold} month threshold)")
                                else:
                                    print(f"        ❌ Review too old: {text} ({months_ago:.1f} months ago - exceeds {months_threshold} month threshold)")
                        else:
                            if text:
                                print(f"        ⚠️ Skipping non-timestamp text: '{text}'")
                    
                    if not review_timestamps:
                        print(f"        ❌ No review timestamps found on this profile")
                    elif not has_recent_review:
                        print(f"        ❌ No recent reviews found within {months_threshold} months")
                    
                    # Log the most recent review found
                    if last_review_date:
                        print(f"        📅 Most recent review date: {last_review_date.strftime('%Y-%m-%d')} ({most_recent_months_ago:.1f} months ago)")
                        
                except Exception as e:
                    print(f"        ⚠️ Error parsing review dates: {e}")
                    # If we can't determine, be conservative and assume no recent reviews
                    has_recent_review = False
                    last_review_date = None
                
                # Close the new tab and switch back
                try:
                    current_handle = self.driver.current_window_handle
                    if current_handle != original_window:
                        self.driver.close()
                        self.driver.switch_to.window(original_window)
                    else:
                        print(f"        ⚠️ Already on original window, no tab to close")
                except Exception as cleanup_error:
                    print(f"        ⚠️ Tab cleanup warning: {cleanup_error}")
                    # Force switch back to original window
                    try:
                        self.driver.switch_to.window(original_window)
                    except:
                        pass
                
                return has_recent_review, last_review_date
                
            except Exception as e:
                print(f"        ❌ Failed to open business profile: {e}")
                # Switch back to original window if something went wrong
                try:
                    # Close any new tabs that might have been opened
                    current_handles = self.driver.window_handles
                    if len(current_handles) > 1:
                        current_handle = self.driver.current_window_handle
                        if current_handle != original_window:
                            self.driver.close()
                    self.driver.switch_to.window(original_window)
                except Exception as final_cleanup:
                    print(f"        ⚠️ Error in final cleanup: {final_cleanup}")
                return False, None
                
        except Exception as e:
            print(f"        ❌ Failed to check recent reviews: {e}")
            return False, None
    
    def _extract_industry_from_query(self, query):
        """Extract industry from search query"""
        try:
            # Simple industry extraction from query
            query_lower = query.lower()
            
            # Common industry patterns
            if 'barber' in query_lower:
                return 'Barber Shops'
            elif 'paint' in query_lower:
                return 'Painters'  
            elif 'restaurant' in query_lower:
                return 'Restaurants'
            elif 'salon' in query_lower or 'hair' in query_lower:
                return 'Hair Salons'
            elif 'auto' in query_lower or 'car' in query_lower:
                return 'Automotive'
            elif 'dentist' in query_lower or 'dental' in query_lower:
                return 'Dental'
            elif 'lawyer' in query_lower or 'attorney' in query_lower:
                return 'Legal Services'
            elif 'plumb' in query_lower:
                return 'Plumbing'
            elif 'electric' in query_lower:
                return 'Electrical'
            elif 'clean' in query_lower:
                return 'Cleaning Services'
            else:
                # Extract first word before "near" if present
                if ' near ' in query_lower:
                    industry_part = query_lower.split(' near ')[0].strip()
                    return industry_part.title()
                else:
                    # Use whole query as industry
                    return query.strip().title()
        except:
            return "Unknown"
    
    def _extract_location_from_query(self, query):
        """Extract location from search query"""
        try:
            query_lower = query.lower()
            
            # Look for "near [location]" pattern
            if ' near ' in query_lower:
                location_part = query_lower.split(' near ')[1].strip()
                return location_part.title()
            else:
                # No location specified
                return "Unknown"
        except:
            return "Unknown"
    
    def _take_business_screenshot(self, business_name, business_element=None):
        """Take a screenshot focusing on the specific business in the search results"""
        try:
            print(f"    📸 Taking business screenshot for: {business_name}")
            
            # Clean business name for filename
            clean_name = "".join(c for c in business_name if c.isalnum() or c in (' ', '-', '_')).rstrip()
            clean_name = clean_name.replace(' ', '_')[:20]  # Limit length
            
            print(f"    📁 Clean filename: business_{clean_name}")
            
            # If we have the business element, scroll it into view and highlight it
            if business_element:
                try:
                    print(f"    🎯 Focusing on business element for screenshot")
                    
                    # Scroll the business element into view
                    self.driver.execute_script("arguments[0].scrollIntoView({behavior: 'smooth', block: 'center'});", business_element)
                    time.sleep(1)  # Wait for smooth scroll to complete
                    
                    # Add a temporary highlight to make the business more visible
                    original_style = business_element.get_attribute('style')
                    self.driver.execute_script("""
                        arguments[0].style.border = '3px solid #ff6b35';
                        arguments[0].style.borderRadius = '8px';
                        arguments[0].style.boxShadow = '0 0 15px rgba(255, 107, 53, 0.5)';
                        arguments[0].style.backgroundColor = 'rgba(255, 107, 53, 0.1)';
                    """, business_element)
                    
                    time.sleep(0.5)  # Brief pause to ensure highlight is applied
                    
                    # Take the screenshot
                    screenshot_filename = self._take_screenshot(f"business_{clean_name}")
                    
                    # Remove the highlight
                    if original_style:
                        self.driver.execute_script("arguments[0].setAttribute('style', arguments[1]);", business_element, original_style)
                    else:
                        self.driver.execute_script("arguments[0].removeAttribute('style');", business_element)
                        
                except Exception as highlight_error:
                    print(f"    ⚠️ Could not highlight business element: {highlight_error}")
                    # Fall back to regular screenshot
                    screenshot_filename = self._take_screenshot(f"business_{clean_name}")
            else:
                # No business element provided, take regular screenshot
                print(f"    📷 Taking regular screenshot (no business element provided)")
                screenshot_filename = self._take_screenshot(f"business_{clean_name}")
            
            if screenshot_filename:
                print(f"    ✅ Business screenshot saved successfully: {screenshot_filename}")
            else:
                print(f"    ❌ Business screenshot save returned None")
                
            return screenshot_filename
            
        except Exception as e:
            print(f"    ❌ Business screenshot failed for {business_name}: {e}")
            import traceback
            print(f"    📋 Traceback: {traceback.format_exc()}")
            return None
    
    def close(self):
        """Close the browser"""
        if self._closed:
            print("\n⚠️ Browser already closed, skipping")
            return
            
        if self.driver:
            try:
                self.driver.quit()
                print("\n✅ Browser closed")
            except Exception as e:
                # Silently handle case where session is already closed/invalid
                print(f"\n⚠️ Browser session already closed: {type(e).__name__}")
            finally:
                self._closed = True


# Update the main.py import to use this enhanced version
if __name__ == "__main__":
    # Test the enhanced automation
    automation = BrowserAutomation(headless=False)
    try:
        results = automation.search_google_maps(
            "Plumber near Austin, TX",
            limit=5,
            min_rating=4.0,
            min_reviews=10
        )
        
        print("\n" + "=" * 60)
        print(f"FOUND {len(results)} QUALIFYING LEADS:")
        print("=" * 60)
        
        for i, lead in enumerate(results, 1):
            print(f"\n{i}. {lead['name']}")
            print(f"   📞 Phone: {lead.get('phone', 'No phone')}")
            print(f"   🌐 Website: {'Yes' if lead.get('has_website') else 'No (CANDIDATE!)'}")
            print(f"   ⭐ Rating: {lead.get('rating', 'N/A')} ({lead.get('reviews', '0')} reviews)")
            print(f"   🔗 {lead.get('url', '')}")
            
    finally:
        automation.close()