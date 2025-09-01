#!/usr/bin/env python3
"""
Google Maps search engine with advanced filtering and iteration
"""

import time
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException, NoSuchElementException
from business_extractor_utils import BusinessExtractorUtils
from database_operations import save_lead_to_database
from job_management import add_job_log


class MapsSearchEngine:
    def __init__(self, driver, screenshot_manager, search_area_manager, job_id=None):
        self.driver = driver
        self.wait = WebDriverWait(driver, 10)
        self.screenshot_manager = screenshot_manager
        self.search_area_manager = search_area_manager
        self.job_id = job_id
        self.cancel_flag = False
        self.business_counter = 0  # Track businesses across all iterations
        self.last_processed_element_id = None  # Track where we left off after scrolling
        self.processed_element_ids = set()  # Track all processed element IDs
        self.enable_pagespeed = False  # Enable PageSpeed testing for new leads
        self.max_pagespeed_score = None  # Maximum acceptable PageSpeed score (set when PageSpeed is enabled)
    
    def _log(self, message):
        """Log message to both console and job logs for WebSocket"""
        print(message)  # Keep console output for debugging
        if self.job_id:
            add_job_log(self.job_id, message)

    def set_cancel_flag(self):
        """Set cancel flag to stop search"""
        self.cancel_flag = True

    def is_cancelled(self):
        """Check if search should be cancelled"""
        return self.cancel_flag

    def search_google_maps(self, query, limit=20, min_rating=0.0, min_reviews=0, 
                          requires_website=None, recent_review_months=None, 
                          min_photos=None, min_description_length=None, enable_click_through=True):
        """Enhanced Google Maps search with proper iteration and scrolling"""
        self._log(f"🚀 ENHANCED MAPS SEARCH ENGINE")
        self._log(f"   Query: {query}, Limit: {limit}, Recent Review Months: {recent_review_months}")
        
        results = []
        processed_names = set()
        evaluated_businesses = set()
        
        self._log_search_criteria(query, limit, min_rating, min_reviews, 
                                 requires_website, recent_review_months, 
                                 min_photos, min_description_length)
        
        try:
            # Navigate to Google Maps and perform search
            if not self._perform_initial_search(query):
                return results
            
            # Main search iteration loop
            results = self._iterate_through_results(
                results, processed_names, evaluated_businesses, query, limit,
                min_rating, min_reviews, requires_website, recent_review_months,
                min_photos, min_description_length, enable_click_through
            )
            
            self._log(f"✅ Search completed! Found {len(results)} qualifying businesses")
            return results
            
        except Exception as e:
            self._log(f"❌ Error in Google Maps search: {str(e)}")
            return results

    def _log_search_criteria(self, query, limit, min_rating, min_reviews, 
                            requires_website, recent_review_months, 
                            min_photos, min_description_length):
        """Log all search criteria for debugging"""
        self._log(f"\n🎯 Search Criteria:")
        self._log(f"   Query: {query}")
        self._log(f"   Limit: {limit} businesses")
        self._log(f"   Min Rating: {min_rating}")
        self._log(f"   Min Reviews: {min_reviews}")
        
        # Website Filter
        if requires_website is None:
            self._log(f"   Website Filter: ANY (all businesses)")
        elif requires_website == False:
            self._log(f"   Website Filter: NO WEBSITE ONLY (ideal prospects)")
        elif requires_website == True:
            self._log(f"   Website Filter: MUST HAVE WEBSITE")
        
        # Recent Review Filter
        if recent_review_months is not None:
            self._log(f"   Recent Reviews: Within {recent_review_months} months")
        else:
            self._log(f"   Recent Reviews: N/A (no recency filter)")
        
        # Additional filters
        if min_photos is not None:
            self._log(f"   Min Photos: {min_photos}+ photos")
        if min_description_length is not None:
            self._log(f"   Min Description: {min_description_length}+ characters")

    def _perform_initial_search(self, query):
        """Navigate to Google Maps and perform initial search"""
        try:
            self._log(f"\n📍 Opening Google Maps...")
            self.driver.get("https://www.google.com/maps")
            time.sleep(2)
            
            self._log(f"🔍 Searching for: {query}")
            search_box = self.wait.until(
                EC.presence_of_element_located((By.ID, "searchboxinput"))
            )
            search_box.clear()
            search_box.send_keys(query)
            search_box.send_keys(Keys.RETURN)
            
            time.sleep(3)
            
            # Verify results panel exists
            try:
                self.wait.until(
                    EC.presence_of_element_located((By.CSS_SELECTOR, "[role='feed']"))
                )
                self._log("✅ Found results panel")
                return True
            except TimeoutException:
                self._log("❌ No results found or results panel not loaded")
                return False
                
        except Exception as e:
            self._log(f"❌ Error performing initial search: {str(e)}")
            return False

    def _iterate_through_results(self, results, processed_names, evaluated_businesses,
                                query, limit, min_rating, min_reviews, requires_website,
                                recent_review_months, min_photos, min_description_length,
                                enable_click_through):
        """Main iteration loop through search results"""
        scroll_attempts = 0
        max_scroll_attempts = 20
        expansions_performed = 0
        max_expansions = 3
        no_new_results_count = 0
        max_no_new_results = 3
        
        while len(results) < limit and scroll_attempts < max_scroll_attempts:
            if self.is_cancelled():
                self._log("🛑 Search cancelled by user")
                break
            
            self._log(f"\n📋 Iteration {scroll_attempts + 1}: Found {len(results)} qualifying businesses so far")
            
            # Take debug screenshot before processing
            if self.screenshot_manager:
                debug_screenshot = f"debug_iteration_{scroll_attempts + 1}_before_processing"
                self.screenshot_manager.take_screenshot(debug_screenshot)
                self._log(f"📸 Debug screenshot: {debug_screenshot}")
            
            # Get current business elements
            business_elements = self._get_business_elements()
            
            if not business_elements:
                self._log("❌ No business elements found")
                break
            
            self._log(f"📊 Found {len(business_elements)} business elements on page")
            
            # Process each business element
            new_results_found = self._process_business_elements(
                business_elements, results, processed_names, evaluated_businesses,
                query, limit, min_rating, min_reviews, requires_website,
                recent_review_months, min_photos, min_description_length,
                enable_click_through
            )
            
            if new_results_found == 0:
                no_new_results_count += 1
                self._log(f"⚠️ No new qualifying results in this iteration ({no_new_results_count}/{max_no_new_results})")
            else:
                no_new_results_count = 0
            
            # Break if we have enough results
            if len(results) >= limit:
                break
            
            # Try scrolling first
            if self.search_area_manager.scroll_results_panel():
                self._log("✅ Scrolled results panel")
                time.sleep(2)
            
            # If no new results for several attempts, try expanding search area
            if (no_new_results_count >= max_no_new_results and 
                expansions_performed < max_expansions):
                
                expansions_performed += 1
                if self.search_area_manager.expand_search_area(expansions_performed, evaluated_businesses, query):
                    no_new_results_count = 0
                    self._log(f"✅ Successfully expanded search area #{expansions_performed}")
                else:
                    self._log(f"❌ Failed to expand search area #{expansions_performed}")
            elif no_new_results_count >= max_no_new_results and expansions_performed >= max_expansions:
                self._log(f"🛑 No new results found after {max_no_new_results} attempts and all expansions exhausted")
                break
            
            scroll_attempts += 1
        
        return results

    def _get_business_elements(self):
        """Get all business elements from the current page"""
        try:
            # Multiple selectors to find business listings
            business_selectors = [
                "[role='feed'] > div",
                ".Nv2PK",
                "div[data-result-index]", 
                ".section-result"
            ]
            
            for selector in business_selectors:
                try:
                    elements = self.driver.find_elements(By.CSS_SELECTOR, selector)
                    if elements:
                        # Return all displayed elements - we'll handle duplicates by business name
                        return [elem for elem in elements if elem.is_displayed()]
                except:
                    continue
            
            return []
        except Exception as e:
            self._log(f"❌ Error getting business elements: {str(e)}")
            return []
    
    def _get_element_identifier(self, element):
        """Get a stable identifier for a business element"""
        try:
            # Try to find a Maps place link which should be stable
            link = element.find_element(By.CSS_SELECTOR, "a[href*='/maps/place/']")
            href = link.get_attribute("href")
            if href:
                # Extract the place ID or coordinates from the URL
                if "/maps/place/" in href:
                    return href.split("/maps/place/")[1].split("?")[0].split("/")[0]
            
            # Fallback: use element position and parent info
            location = element.location
            size = element.size
            return f"{location['x']}_{location['y']}_{size['width']}_{size['height']}"
            
        except:
            return None
    
    def _get_all_business_elements(self):
        """Get all business elements without filtering (for debugging)"""
        try:
            business_selectors = [
                "[role='feed'] > div",
                ".Nv2PK",
                "div[data-result-index]", 
                ".section-result"
            ]
            
            for selector in business_selectors:
                try:
                    elements = self.driver.find_elements(By.CSS_SELECTOR, selector)
                    if elements:
                        return [elem for elem in elements if elem.is_displayed()]
                except:
                    continue
            
            return []
        except:
            return []

    def _process_business_elements(self, business_elements, results, processed_names,
                                  evaluated_businesses, query, limit, min_rating,
                                  min_reviews, requires_website, recent_review_months,
                                  min_photos, min_description_length, enable_click_through):
        """Process business elements starting from where we left off after scrolling"""
        new_results_count = 0
        elements_processed_this_iteration = 0
        elements_skipped_as_duplicates = 0
        start_processing = False
        
        # If this is the first iteration, start processing immediately
        if self.last_processed_element_id is None:
            start_processing = True
            self._log("🔄 First iteration - processing from beginning")
        else:
            self._log(f"🔄 Continuing from last processed element ID: {self.last_processed_element_id}")
        
        # Check if we can find the last processed element in current elements
        found_last_processed = False
        if not start_processing:
            for element in business_elements:
                element_id = self._get_element_identifier(element)
                if element_id == self.last_processed_element_id:
                    found_last_processed = True
                    break
            
            if not found_last_processed:
                self._log("⚠️ Last processed element not found in current batch - starting fresh with new elements")
                start_processing = True
        
        for i, business_element in enumerate(business_elements):
            if len(results) >= limit or self.is_cancelled():
                break
            
            try:
                # Get unique identifier for this element
                element_id = self._get_element_identifier(business_element)
                if not element_id:
                    continue
                
                # If we haven't started processing yet, check if this is where we left off
                if not start_processing:
                    if element_id == self.last_processed_element_id:
                        self._log(f"📍 Found where we left off! Resuming from next element...")
                        start_processing = True
                    continue  # Skip until we find our starting point
                
                # Skip if we already processed this specific element (by ID, not name)
                if element_id in self.processed_element_ids:
                    elements_skipped_as_duplicates += 1
                    continue
                
                # Mark this element as processed by ID
                self.processed_element_ids.add(element_id)
                
                # Extract FULL business details
                try:
                    from business_extractor import extract_business_details
                    business_details = extract_business_details(business_element, driver=self.driver, enable_click_through=enable_click_through)
                except Exception as e:
                    self._log(f"    ⚠️ Full extraction failed, trying basic extraction: {e}")
                    business_details = self._extract_business_from_element(business_element)
                
                if not business_details or not business_details.get('name'):
                    self._log(f"❌ No business name found for element {i+1}")
                    # Update last processed even for failed extractions to avoid getting stuck
                    self.last_processed_element_id = element_id
                    continue
                
                business_name = business_details['name']
                
                # Skip if already processed by business name (final safeguard)
                if business_name in evaluated_businesses:
                    elements_skipped_as_duplicates += 1
                    self.last_processed_element_id = element_id
                    continue
                
                evaluated_businesses.add(business_name)
                self.business_counter += 1
                elements_processed_this_iteration += 1
                
                self._log(f"\n{'='*60}")
                self._log(f"🏢 [{self.business_counter}] Evaluating: {business_name}")
                self._log(f"{'='*60}")
                
                # Update last processed element ID
                self.last_processed_element_id = element_id
                
                # Apply filters with reason tracking
                filter_result = self._passes_all_filters_with_reason(business_details, min_rating, min_reviews,
                                          requires_website, recent_review_months,
                                          min_photos, min_description_length,
                                          business_element)
                
                if filter_result["passes"]:
                    
                    if business_name not in processed_names:
                        # We already have full details - no need for second extraction
                        
                        # Re-check website filter after full extraction (critical for accurate filtering)
                        if requires_website is not None:
                            final_has_website = business_details.get('has_website', False)
                            if requires_website and not final_has_website:
                                self._log(f"❌ Business filtered out after full extraction: {business_name}")
                                self._log(f"    Reason: Missing required website (discovered after full extraction)")
                                continue
                            if not requires_website and final_has_website:
                                self._log(f"❌ Business filtered out after full extraction: {business_name}")
                                self._log(f"    Reason: Has website (looking for businesses without websites)")
                                continue
                        
                        # Take business screenshot (handle stale element after click-through)
                        try:
                            screenshot_filename = self.screenshot_manager.take_business_screenshot(
                                business_name, business_element
                            )
                            business_details['screenshot_filename'] = screenshot_filename
                        except Exception as screenshot_error:
                            if "stale element" in str(screenshot_error).lower():
                                self._log(f"    ⚠️ Business element became stale after click-through, taking general screenshot instead")
                                screenshot_filename = self.screenshot_manager.take_screenshot(f"business_{business_name.lower().replace(' ', '_')}")
                                business_details['screenshot_filename'] = screenshot_filename
                            else:
                                self._log(f"    ❌ Screenshot error: {screenshot_error}")
                                business_details['screenshot_filename'] = None
                        
                        # Extract additional details
                        business_details['industry'] = BusinessExtractorUtils.extract_industry_from_query(query)
                        business_details['location'] = BusinessExtractorUtils.extract_location_from_query(query)
                        
                        # Save to database and add to results
                        lead_id = save_lead_to_database(business_details, self.job_id, self.enable_pagespeed, self.max_pagespeed_score)
                        if lead_id:
                            business_details['lead_id'] = lead_id
                            results.append(business_details)
                            processed_names.add(business_name)
                            new_results_count += 1
                            self._log(f"✅ Added qualifying business #{len(results)}: {business_name}")
                    else:
                        self._log(f"⚠️ Duplicate business skipped: {business_name}")
                else:
                    self._log(f"❌ Business filtered out: {business_name}")
                    self._log(f"    Reason: {filter_result['reason']}")
                
            except Exception as e:
                self._log(f"❌ Error processing business element: {str(e)}")
                continue
        
        # Log iteration summary
        self._log(f"\n📊 Iteration Summary:")
        self._log(f"   - Total elements found: {len(business_elements)}")
        self._log(f"   - Elements processed: {elements_processed_this_iteration}")
        self._log(f"   - Elements skipped (duplicates): {elements_skipped_as_duplicates}")
        self._log(f"   - New qualifying results: {new_results_count}")
        
        return new_results_count

    def _extract_business_from_element(self, element):
        """Extract basic business details for screening (name, rating, etc.)"""
        # Only extract minimal info needed for filtering - no website detection yet
        try:
            from business_extractor import StandardListingExtractor
            extractor = StandardListingExtractor()
            # Use _extract_basic_info which doesn't include website detection logging
            return extractor._extract_basic_info(element)
        except:
            # Fallback basic extraction
            return self._basic_business_extraction(element)

    def _basic_business_extraction(self, element):
        """Basic business detail extraction fallback"""
        try:
            business_details = {}
            
            # Try to find business name
            name_selectors = ['.section-result-title', '.qBF1Pd', 'h3', '[data-result-title]']
            for selector in name_selectors:
                try:
                    name_elem = element.find_element(By.CSS_SELECTOR, selector)
                    business_details['name'] = name_elem.text.strip()
                    break
                except:
                    continue
            
            # Try to find rating
            rating_selectors = ['.MW4etd', '.section-result-rating', '[data-rating]']
            for selector in rating_selectors:
                try:
                    rating_elem = element.find_element(By.CSS_SELECTOR, selector)
                    rating_text = rating_elem.text.strip()
                    business_details['rating'] = float(rating_text.split()[0])
                    break
                except:
                    continue
            
            return business_details if business_details.get('name') else None
            
        except Exception as e:
            self._log(f"❌ Error in basic business extraction: {str(e)}")
            return None

    def _passes_all_filters_with_reason(self, business_details, min_rating, min_reviews,
                                       requires_website, recent_review_months, min_photos,
                                       min_description_length, business_element):
        """Check if business passes all applied filters and return reason if not"""
        try:
            # Rating filter - ensure proper type conversion
            rating_value = business_details.get('rating', 0)
            if isinstance(rating_value, str):
                try:
                    rating_value = float(rating_value)
                except (ValueError, TypeError):
                    rating_value = 0.0
            if rating_value < min_rating:
                return {"passes": False, "reason": f"Rating {rating_value} below minimum {min_rating}"}
            
            # Review count filter - ensure proper type conversion
            reviews_value = business_details.get('reviews', 0)
            if isinstance(reviews_value, str):
                try:
                    reviews_value = int(reviews_value)
                except (ValueError, TypeError):
                    reviews_value = 0
            if reviews_value < min_reviews:
                return {"passes": False, "reason": f"Review count {reviews_value} below minimum {min_reviews}"}
            
            # Website filter
            if requires_website is not None:
                has_website = business_details.get('has_website', False)
                if requires_website and not has_website:
                    return {"passes": False, "reason": "Missing required website"}
                if not requires_website and has_website:
                    return {"passes": False, "reason": "Has website (looking for businesses without websites)"}
            
            # Recent reviews filter - use proper click-through checking
            if recent_review_months is not None:
                # First try quick check from list view
                from business_extractor_utils import BusinessExtractorUtils
                quick_check = BusinessExtractorUtils.check_recent_reviews_profile(
                    business_element, recent_review_months
                )
                
                # If quick check finds recent reviews, we're good
                if quick_check:
                    self._log(f"    ✅ Quick check found recent reviews")
                else:
                    # Need to click into business for detailed check
                    self._log(f"    🔍 Quick check inconclusive, performing detailed check...")
                    from review_date_checker import ReviewDateChecker
                    has_recent_reviews, most_recent = ReviewDateChecker.check_reviews_with_click(
                        self.driver, business_element, recent_review_months
                    )
                    if not has_recent_reviews:
                        return {"passes": False, "reason": f"No reviews within last {recent_review_months} months"}
            
            return {"passes": True, "reason": ""}
            
        except Exception as e:
            self._log(f"❌ Error applying filters: {str(e)}")
            return {"passes": False, "reason": f"Filter error: {str(e)}"}

    def _passes_all_filters(self, business_details, min_rating, min_reviews,
                           requires_website, recent_review_months, min_photos,
                           min_description_length, business_element):
        """Check if business passes all applied filters (legacy method)"""
        result = self._passes_all_filters_with_reason(business_details, min_rating, min_reviews,
                                                     requires_website, recent_review_months, min_photos,
                                                     min_description_length, business_element)
        return result["passes"]