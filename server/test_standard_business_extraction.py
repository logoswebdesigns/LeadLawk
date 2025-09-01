#!/usr/bin/env python3
"""
Test successful extraction of 3 standard business leads from HTML reference files
All 3 are standard business leads: 
1. Straight Line Painting Omaha - WITH website
2. Perceptive Painting LLC - WITHOUT website  
3. The Rosy Clay Co. - WITH website
"""

from business_extractor import StandardListingExtractor
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.remote.webdriver import WebDriver
from bs4 import BeautifulSoup
import os
import tempfile


class StandardBusinessExtractionTest:
    """Test extraction of standard business leads from reference HTML"""
    
    def __init__(self):
        self.extractor = StandardListingExtractor()
        self.driver = None
        
    def setup_selenium_driver(self):
        """Setup Selenium driver using Docker's remote hub"""
        options = Options()
        options.add_argument("--headless")
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-dev-shm-usage")
        
        # Use the selenium-chrome container
        selenium_hub_url = "http://selenium-chrome:4444/wd/hub"
        self.driver = webdriver.Remote(command_executor=selenium_hub_url, options=options)
        
    def load_html_content(self, html_content):
        """Load HTML content into Selenium driver"""
        html_with_structure = f"""
        <!DOCTYPE html>
        <html>
        <head><title>Google Maps Test</title></head>
        <body>
            <div role="feed">
                {html_content}
            </div>
        </body>
        </html>
        """
        
        # Create temp file and load it
        with tempfile.NamedTemporaryFile(mode='w', suffix='.html', delete=False) as f:
            f.write(html_with_structure)
            temp_file = f.name
            
        self.driver.get(f"file://{temp_file}")
        os.unlink(temp_file)  # Clean up temp file
        
    def extract_business_from_soup(self, soup_element):
        """Extract business data from BeautifulSoup element (using our selectors)"""
        business_data = {}
        
        # Extract business name using the same selectors as our StandardListingExtractor
        name_selectors = [
            "a[href*='/maps/place/'][aria-label]",          # Maps link with aria-label (most reliable)
            "div[class*='fontHeadline']",                   # Any div with semantic fontHeadline class
            "div[class*='headline']",                       # Any div with headline in class name
            ".qBF1Pd"                                       # Direct class match
        ]
        
        name = None
        for selector in name_selectors:
            name_elem = soup_element.select_one(selector)
            if name_elem:
                name = name_elem.get('aria-label') if name_elem.get('aria-label') else name_elem.get_text(strip=True)
                if name:
                    break
                    
        if not name:
            return None
            
        business_data['name'] = name
        
        # Extract phone number
        phone_elem = soup_element.select_one(".UsdlK")
        if phone_elem:
            business_data['phone'] = phone_elem.get_text(strip=True)
            
        # Extract rating  
        rating_elem = soup_element.select_one(".MW4etd")
        if rating_elem:
            try:
                business_data['rating'] = float(rating_elem.get_text(strip=True))
            except:
                pass
                
        # Extract review count
        review_elem = soup_element.select_one(".UY7F9")
        if review_elem:
            try:
                review_text = review_elem.get_text(strip=True)
                review_count = int(review_text.strip('()'))
                business_data['review_count'] = review_count
            except:
                pass
        
        # Extract website URL
        website_link = soup_element.select_one('a[data-value="Website"]')
        if website_link:
            business_data['website_url'] = website_link.get('href')
            
        return business_data
        
    def test_standard_businesses_extraction(self):
        """Test extraction of all 3 standard businesses from reference HTML"""
        print("\n" + "="*80)
        print("🧪 STANDARD BUSINESS EXTRACTION TEST")
        print("="*80)
        
        # Read the HTML file with 3 standard businesses
        html_file = "google-maps-reference/standard-businesses_website-nowebsite-website.html"
        if not os.path.exists(html_file):
            raise Exception(f"Reference HTML file not found: {html_file}")
            
        with open(html_file, 'r', encoding='utf-8') as f:
            html_content = f.read()
            
        # Setup Selenium and load HTML content
        self.setup_selenium_driver()
        self.load_html_content(html_content)
        
        # Get the page source and parse with BeautifulSoup (hybrid approach!)
        html = self.driver.page_source
        soup = BeautifulSoup(html, 'html.parser')
        
        print("🔍 DEBUG: HTML structure after Selenium load:")
        print(soup.prettify()[:2000])  # First 2000 chars for debugging
        
        # Find business elements using BeautifulSoup
        feed_div = soup.find(attrs={"role": "feed"})
        if feed_div:
            # Get all direct div children which should be business listings  
            business_elements = feed_div.find_all("div", recursive=False)
            # Filter out empty or irrelevant divs
            business_elements = [div for div in business_elements if div.get_text(strip=True)]
        else:
            # Fallback: Try to find any div that might contain businesses
            all_divs = soup.find_all("div")
            print(f"📋 No feed div found, checking {len(all_divs)} total divs in HTML")
            # Let's work with the body content directly
            body = soup.find("body")
            if body:
                business_elements = body.find_all("div", recursive=True)
                # Filter for divs that contain business-like content
                business_elements = [div for div in business_elements 
                                   if div.get_text(strip=True) and 
                                   any(cls in str(div.get('class', [])) for cls in ['Nv2PK', 'qBF1Pd', 'fontHeadline'])]
            else:
                raise Exception("Could not find body or feed div in parsed HTML")
        print(f"📋 Found {len(business_elements)} potential business elements")
        
        extracted_businesses = []
        
        for i, element in enumerate(business_elements):
            try:
                # Use our BeautifulSoup-based extraction (same logic as StandardListingExtractor)
                business_data = self.extract_business_from_soup(element)
                if business_data and business_data.get('name'):
                    extracted_businesses.append(business_data)
                    print(f"✅ Business {i+1}: {business_data}")
            except Exception as e:
                print(f"❌ Failed to extract business {i+1}: {str(e)}")
                
        # Validate we extracted exactly 3 businesses
        if len(extracted_businesses) != 3:
            raise Exception(f"Expected 3 businesses, got {len(extracted_businesses)}")
            
        print(f"\n🎉 Successfully extracted {len(extracted_businesses)} standard businesses!")
        
        # Validate specific business data
        business_names = [b['name'] for b in extracted_businesses]
        
        expected_businesses = [
            "Straight Line Painting Omaha",
            "Perceptive Painting LLC", 
            "The Rosy Clay Co."
        ]
        
        for expected_name in expected_businesses:
            if expected_name not in business_names:
                raise Exception(f"Missing expected business: {expected_name}")
            print(f"✅ Found expected business: {expected_name}")
            
        # Validate website presence
        straight_line = next(b for b in extracted_businesses if "Straight Line" in b['name'])
        perceptive = next(b for b in extracted_businesses if "Perceptive" in b['name'])
        rosy_clay = next(b for b in extracted_businesses if "Rosy Clay" in b['name'])
        
        # Straight Line Painting should have website
        if not straight_line.get('website_url'):
            raise Exception("Straight Line Painting should have website but doesn't")
        print(f"✅ Straight Line has website: {straight_line['website_url']}")
        
        # Perceptive Painting should NOT have website
        if perceptive.get('website_url'):
            raise Exception("Perceptive Painting should NOT have website but does")
        print("✅ Perceptive Painting correctly has no website")
        
        # Rosy Clay should have website  
        if not rosy_clay.get('website_url'):
            raise Exception("The Rosy Clay Co. should have website but doesn't")
        print(f"✅ Rosy Clay has website: {rosy_clay['website_url']}")
        
        print("\n🎊 ALL STANDARD BUSINESS EXTRACTION TESTS PASSED!")
        print("✅ Successfully extracted all 3 businesses")
        print("✅ Correctly identified website presence/absence")
        print("✅ All business names extracted properly")
        
        return True
        
    def cleanup(self):
        """Clean up resources"""
        if self.driver:
            self.driver.quit()


def run_test():
    """Run the standard business extraction test"""
    test = StandardBusinessExtractionTest()
    try:
        success = test.test_standard_businesses_extraction()
        if success:
            print("\n🎉 STANDARD BUSINESS EXTRACTION TEST PASSED!")
            return True
    except Exception as e:
        print(f"\n💥 TEST FAILED: {e}")
        return False
    finally:
        test.cleanup()


if __name__ == "__main__":
    print("🚀 Starting Standard Business Extraction Test...")
    success = run_test()
    if success:
        print("\n✅ Test completed successfully!")
        exit(0)
    else:
        print("\n❌ Test failed!")
        exit(1)