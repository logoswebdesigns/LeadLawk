"""
Review Date Checker Module
Handles clicking into businesses and checking review dates properly
"""

import re
import time
from datetime import datetime, timedelta
from selenium.webdriver.common.by import By
from selenium.webdriver.support.wait import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException, NoSuchElementException


class ReviewDateChecker:
    """Handles review date checking with proper click-through"""
    
    @staticmethod
    def check_reviews_with_click(driver, business_element, months_threshold=24):
        """
        Click into business, navigate to Reviews tab, and check review dates
        
        Args:
            driver: Selenium WebDriver instance
            business_element: The business element to click into
            months_threshold: Number of months to check for recent reviews
            
        Returns:
            tuple: (has_recent_reviews: bool, most_recent_date: str or None)
        """
        print(f"    🔍 Checking reviews with click-through (threshold: {months_threshold} months)")
        
        # Save original window handle
        original_window = driver.current_window_handle
        original_url = driver.current_url
        
        try:
            # Find and click the business link
            business_link = business_element.find_element(By.CSS_SELECTOR, "a[href*='/maps/place/']")
            business_url = business_link.get_attribute("href")
            business_name = business_link.get_attribute("aria-label") or "Unknown Business"
            
            print(f"    🖱️ Clicking into {business_name} to check reviews...")
            
            # Open in new tab to preserve state
            driver.execute_script("window.open(arguments[0]);", business_url)
            time.sleep(1)
            
            # Switch to new tab
            new_window = [w for w in driver.window_handles if w != original_window][0]
            driver.switch_to.window(new_window)
            
            # Wait for page to load
            WebDriverWait(driver, 10).until(
                EC.presence_of_element_located((By.CSS_SELECTOR, "h1, [role='heading']"))
            )
            
            # Click Reviews tab
            reviews_clicked = ReviewDateChecker._click_reviews_tab(driver)
            
            if reviews_clicked:
                # Try to sort by newest
                ReviewDateChecker._sort_by_newest(driver)
            
            # Check review dates
            has_recent, most_recent = ReviewDateChecker._check_review_dates(driver, months_threshold)
            
            # Close tab and return to original
            driver.close()
            driver.switch_to.window(original_window)
            
            if has_recent:
                print(f"    ✅ Found recent reviews (within {months_threshold} months)")
            else:
                print(f"    ❌ No recent reviews found (older than {months_threshold} months)")
                
            return has_recent, most_recent
            
        except Exception as e:
            print(f"    ❌ Error checking reviews: {e}")
            # Clean up - try to return to original state
            try:
                if len(driver.window_handles) > 1:
                    driver.close()
                driver.switch_to.window(original_window)
            except:
                pass
            
            # Default to True (assume recent) when we can't check
            return True, None
    
    @staticmethod
    def _click_reviews_tab(driver):
        """Click the Reviews tab"""
        try:
            # Selectors for Reviews tab based on actual Google Maps structure
            reviews_selectors = [
                "button[role='tab'][aria-label*='Reviews']",
                "button[role='tab'][aria-label*='reviews']",
                "button[data-value='Reviews']",
                "//button[@role='tab']//div[contains(text(), 'Reviews')]/ancestor::button",
                "//button[contains(@aria-label, 'Reviews')]",
            ]
            
            reviews_tab = None
            
            # Try CSS selectors first
            for selector in reviews_selectors[:3]:
                try:
                    reviews_tab = driver.find_element(By.CSS_SELECTOR, selector)
                    print(f"    📑 Found Reviews tab with: {selector}")
                    break
                except:
                    continue
            
            # Try XPath if CSS fails
            if not reviews_tab:
                for xpath in reviews_selectors[3:]:
                    try:
                        reviews_tab = driver.find_element(By.XPATH, xpath)
                        print(f"    📑 Found Reviews tab with XPath")
                        break
                    except:
                        continue
            
            if reviews_tab:
                driver.execute_script("arguments[0].click();", reviews_tab)
                time.sleep(2)  # Wait for reviews to load
                print(f"    ✅ Clicked Reviews tab")
                return True
            else:
                print(f"    ⚠️ Could not find Reviews tab")
                return False
                
        except Exception as e:
            print(f"    ⚠️ Error clicking Reviews tab: {e}")
            return False
    
    @staticmethod
    def _sort_by_newest(driver):
        """Sort reviews by newest"""
        try:
            # Find Sort button
            sort_selectors = [
                "button[aria-label*='Sort']",
                "button[data-value='Sort']",
                "//button[contains(@aria-label, 'Sort')]",
                "//span[contains(text(), 'Sort')]/ancestor::button"
            ]
            
            sort_button = None
            
            for selector in sort_selectors:
                try:
                    if selector.startswith("//"):
                        sort_button = driver.find_element(By.XPATH, selector)
                    else:
                        sort_button = driver.find_element(By.CSS_SELECTOR, selector)
                    break
                except:
                    continue
            
            if sort_button:
                driver.execute_script("arguments[0].click();", sort_button)
                time.sleep(1)
                
                # Click Newest option
                newest_selectors = [
                    "div[role='menuitem'][aria-label*='Newest']",
                    "[data-value='Newest']",
                    "//div[@role='menuitem'][contains(text(), 'Newest')]",
                    "//div[contains(@aria-label, 'Newest')]"
                ]
                
                for selector in newest_selectors:
                    try:
                        if selector.startswith("//"):
                            newest = driver.find_element(By.XPATH, selector)
                        else:
                            newest = driver.find_element(By.CSS_SELECTOR, selector)
                        driver.execute_script("arguments[0].click();", newest)
                        time.sleep(2)
                        print(f"    ✅ Sorted by newest")
                        return True
                    except:
                        continue
                        
            return False
            
        except Exception as e:
            print(f"    ⚠️ Could not sort reviews: {e}")
            return False
    
    @staticmethod
    def _check_review_dates(driver, months_threshold):
        """Check review dates on the page"""
        try:
            # Selectors for review timestamps
            timestamp_selectors = [
                ".rsqaWe",  # Google's review timestamp class
                "span[class*='rsqaWe']",
                "[aria-label*='ago']",
                "span:contains('ago')",
                "//span[contains(text(), 'ago')]",
                "//span[contains(text(), 'month')]",
                "//span[contains(text(), 'week')]",
                "//span[contains(text(), 'day')]"
            ]
            
            timestamps = []
            
            for selector in timestamp_selectors:
                try:
                    if selector.startswith("//") or "contains" in selector:
                        elements = driver.find_elements(By.XPATH, selector.replace(":contains", "[contains(text()"))
                    else:
                        elements = driver.find_elements(By.CSS_SELECTOR, selector)
                    timestamps.extend(elements)
                except:
                    continue
            
            if not timestamps:
                print(f"    ⚠️ No review timestamps found")
                return True, None  # Default to True when can't find
            
            print(f"    📅 Found {len(timestamps)} potential timestamps")
            
            cutoff_date = datetime.now() - timedelta(days=months_threshold * 30)
            most_recent_date = None
            
            for element in timestamps[:10]:  # Check first 10
                try:
                    text = element.text.lower().strip()
                    if not text:
                        continue
                        
                    print(f"    🕒 Checking: '{text}'")
                    
                    # Parse the timestamp
                    is_recent, parsed_date = ReviewDateChecker._parse_timestamp(text, cutoff_date)
                    
                    if is_recent:
                        print(f"    ✅ Found recent review: {text}")
                        return True, text
                        
                    if parsed_date and (not most_recent_date or parsed_date > most_recent_date):
                        most_recent_date = parsed_date
                        
                except Exception as e:
                    continue
            
            # If we found dates but none are recent
            if most_recent_date:
                print(f"    ❌ Most recent review is older than {months_threshold} months")
                return False, str(most_recent_date)
            
            # Default to True if we can't parse any dates
            print(f"    ⚠️ Could not parse review dates - assuming recent")
            return True, None
            
        except Exception as e:
            print(f"    ❌ Error checking review dates: {e}")
            return True, None  # Default to True on error
    
    @staticmethod
    def _parse_timestamp(text, cutoff_date):
        """Parse a timestamp and check if it's recent"""
        text = text.lower().strip()
        
        # Common patterns
        patterns = {
            'hours': r'(\d+)\s*hours?\s*ago',
            'days': r'(\d+)\s*days?\s*ago',
            'weeks': r'(\d+)\s*weeks?\s*ago',
            'months': r'(\d+)\s*months?\s*ago',
            'years': r'(\d+)\s*years?\s*ago',
            'a_day': r'a day ago',
            'a_week': r'a week ago',
            'a_month': r'a month ago',
            'a_year': r'a year ago'
        }
        
        now = datetime.now()
        
        # Check each pattern
        for period, pattern in patterns.items():
            match = re.search(pattern, text)
            if match:
                if period == 'hours':
                    return True, now  # Hours ago is always recent
                elif period == 'days':
                    days = int(match.group(1))
                    date = now - timedelta(days=days)
                    return date >= cutoff_date, date
                elif period == 'weeks':
                    weeks = int(match.group(1))
                    date = now - timedelta(weeks=weeks)
                    return date >= cutoff_date, date
                elif period == 'months':
                    months = int(match.group(1))
                    date = now - timedelta(days=months*30)
                    return date >= cutoff_date, date
                elif period == 'years':
                    years = int(match.group(1))
                    date = now - timedelta(days=years*365)
                    return date >= cutoff_date, date
                elif period == 'a_day':
                    return True, now - timedelta(days=1)
                elif period == 'a_week':
                    return True, now - timedelta(weeks=1)
                elif period == 'a_month':
                    date = now - timedelta(days=30)
                    return date >= cutoff_date, date
                elif period == 'a_year':
                    date = now - timedelta(days=365)
                    return date >= cutoff_date, date
        
        # Check for absolute dates (e.g., "November 2024")
        current_year = now.year
        if str(current_year) in text:
            return True, now  # Current year is recent
        elif str(current_year - 1) in text:
            # Last year - check month
            months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun',
                     'jul', 'aug', 'sep', 'oct', 'nov', 'dec']
            for i, month in enumerate(months, 1):
                if month in text:
                    date = datetime(current_year - 1, i, 1)
                    return date >= cutoff_date, date
            # No month found, assume end of year
            date = datetime(current_year - 1, 12, 31)
            return date >= cutoff_date, date
        
        return False, None