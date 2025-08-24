"""
Google Maps Scraper using Selenium
Finds businesses without websites in a specific category and location
"""

import time
import re
from datetime import datetime, timedelta
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from selenium.common.exceptions import TimeoutException, NoSuchElementException
from webdriver_manager.chrome import ChromeDriverManager
import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import SessionLocal
from models import Lead, LeadStatus


class GoogleMapsScraper:
    def __init__(self, headless=True, job_id=None):
        self.job_id = job_id
        self.setup_driver(headless)
        
    def setup_driver(self, headless):
        """Setup Chrome driver with appropriate options"""
        chrome_options = Options()
        if headless:
            # Use new headless for recent Chrome versions
            chrome_options.add_argument("--headless=new")
        chrome_options.add_argument("--no-sandbox")
        chrome_options.add_argument("--disable-dev-shm-usage")
        chrome_options.add_argument("--disable-blink-features=AutomationControlled")
        chrome_options.add_experimental_option("excludeSwitches", ["enable-automation"])
        chrome_options.add_experimental_option('useAutomationExtension', False)
        
        # Try system chromedriver first, else use webdriver-manager to download
        try:
            self.driver = webdriver.Chrome(options=chrome_options)
        except Exception:
            service = Service(ChromeDriverManager().install())
            self.driver = webdriver.Chrome(service=service, options=chrome_options)
        self.wait = WebDriverWait(self.driver, 10)
        
    def search_google_maps(self, query, location):
        """Search Google Maps for businesses"""
        search_query = f"{query} near {location}"
        url = f"https://www.google.com/maps/search/{search_query.replace(' ', '+')}"
        
        self.driver.get(url)
        time.sleep(3)  # Wait for initial load
        
        # Wait for results to load
        try:
            self.wait.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[role='article']")))
        except TimeoutException:
            print(f"No results found for {search_query}")
            return []
            
    def extract_business_info(self, element):
        """Extract business information from a result element"""
        try:
            info = {}
            
            # Business name
            name_elem = element.find_element(By.CSS_SELECTOR, "a[aria-label]")
            info['business_name'] = name_elem.get_attribute("aria-label")
            
            # Click to open details
            name_elem.click()
            time.sleep(2)
            
            # Extract details from side panel
            details_panel = self.wait.until(
                EC.presence_of_element_located((By.CSS_SELECTOR, "div[role='main']"))
            )
            
            # Phone number
            try:
                phone_elem = details_panel.find_element(By.CSS_SELECTOR, "button[data-tooltip*='phone']")
                info['phone'] = phone_elem.get_attribute("aria-label").replace("Phone:", "").strip()
            except NoSuchElementException:
                info['phone'] = None
                
            # Website
            try:
                website_elem = details_panel.find_element(By.CSS_SELECTOR, "a[data-tooltip*='website']")
                info['website_url'] = website_elem.get_attribute("href")
                info['has_website'] = True
            except NoSuchElementException:
                info['website_url'] = None
                info['has_website'] = False
                
            # Rating
            try:
                rating_elem = details_panel.find_element(By.CSS_SELECTOR, "span[role='img'][aria-label*='stars']")
                rating_text = rating_elem.get_attribute("aria-label")
                info['rating'] = float(re.search(r'([\d.]+)', rating_text).group(1))
            except (NoSuchElementException, AttributeError):
                info['rating'] = None
                
            # Review count
            try:
                review_elem = details_panel.find_element(By.CSS_SELECTOR, "button[aria-label*='reviews']")
                review_text = review_elem.get_attribute("aria-label")
                review_match = re.search(r'(\d+)', review_text)
                info['review_count'] = int(review_match.group(1)) if review_match else 0
            except (NoSuchElementException, AttributeError):
                info['review_count'] = 0
                
            # Profile URL
            info['profile_url'] = self.driver.current_url
            
            return info
            
        except Exception as e:
            print(f"Error extracting business info: {e}")
            return None
            
    def scrape(self, industry, location, limit=50, min_rating=4.0, min_reviews=3):
        """Main scraping function"""
        results = []
        
        try:
            self.search_google_maps(industry, location)
            
            # Scroll to load more results
            results_container = self.driver.find_element(By.CSS_SELECTOR, "div[role='feed']")
            
            for _ in range(min(5, limit // 10)):  # Scroll up to 5 times
                self.driver.execute_script("arguments[0].scrollTop = arguments[0].scrollHeight", results_container)
                time.sleep(2)
                
            # Get all business elements
            business_elements = self.driver.find_elements(By.CSS_SELECTOR, "[role='article']")
            
            for idx, element in enumerate(business_elements[:limit]):
                if idx % 10 == 0:
                    print(f"Processing business {idx + 1}/{min(len(business_elements), limit)}")
                    
                info = self.extract_business_info(element)
                
                if info and info.get('phone'):
                    # Filter based on criteria
                    meets_rating = info.get('rating', 0) >= min_rating
                    has_enough_reviews = info.get('review_count', 0) >= min_reviews
                    no_website = not info.get('has_website', True)
                    
                    info.update({
                        'industry': industry,
                        'location': location,
                        'source': 'google_maps',
                        'meets_rating_threshold': meets_rating,
                        'is_candidate': meets_rating and has_enough_reviews and no_website,
                        'last_review_date': datetime.utcnow() - timedelta(days=30),  # Placeholder
                        'has_recent_reviews': True,
                    })
                    
                    results.append(info)
                    self.save_to_db(info)
                    
                # Go back to results list
                self.driver.back()
                time.sleep(1)
                
        except Exception as e:
            print(f"Scraping error: {e}")
            
        finally:
            self.driver.quit()
            
        return results
        
    def save_to_db(self, item):
        """Save lead to database"""
        db = SessionLocal()
        try:
            existing = db.query(Lead).filter(
                Lead.business_name == item['business_name'],
                Lead.phone == item['phone']
            ).first()
            
            if existing:
                for key, value in item.items():
                    setattr(existing, key, value)
                existing.updated_at = datetime.utcnow()
            else:
                lead = Lead(**item)
                db.add(lead)
                
            db.commit()
        finally:
            db.close()


if __name__ == "__main__":
    # Test the scraper
    scraper = GoogleMapsScraper(headless=False)
    results = scraper.scrape("Plumber", "Omaha, NE", limit=10)
    print(f"Found {len(results)} businesses without websites")
    for r in results:
        if r['is_candidate']:
            print(f"- {r['business_name']}: {r['phone']} (Rating: {r.get('rating', 'N/A')})")
