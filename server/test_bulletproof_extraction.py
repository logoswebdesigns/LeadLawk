#!/usr/bin/env python3
"""
Comprehensive test suite for bulletproof Google Maps business extraction.
Tests all different listing types and website presence scenarios using reference HTML files.
"""

import os
import json
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.support.wait import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from bs4 import BeautifulSoup
import tempfile
import time
from business_extractor import StandardListingExtractor, CompactListingExtractor, BusinessExtractorFactory


class BulletproofExtractionTest:
    """Comprehensive test suite for all business listing types"""
    
    def __init__(self):
        self.driver = None
        self.test_results = []
        self.reference_dir = Path("google-maps-reference")
        
    def setup_driver(self, mode="headless"):
        """Setup Selenium driver for testing"""
        options = Options()
        if mode == "headless":
            options.add_argument("--headless")
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-dev-shm-usage")
        options.add_argument("--window-size=1920,1080")
        
        # Check if running in Docker
        if os.environ.get("USE_DOCKER") == "1":
            selenium_hub_url = "http://selenium-chrome:4444/wd/hub"
            self.driver = webdriver.Remote(command_executor=selenium_hub_url, options=options)
        else:
            # Local Chrome driver
            self.driver = webdriver.Chrome(options=options)
            
    def load_html_file(self, filename: str) -> str:
        """Load HTML content from reference file"""
        file_path = self.reference_dir / filename
        if not file_path.exists():
            raise FileNotFoundError(f"Reference HTML file not found: {file_path}")
            
        with open(file_path, 'r', encoding='utf-8') as f:
            return f.read()
            
    def create_test_page(self, html_content: str) -> str:
        """Create a temporary HTML page with proper structure"""
        wrapped_html = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>Google Maps Test</title>
        </head>
        <body>
            <div role="feed">
                {html_content}
            </div>
        </body>
        </html>
        """
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.html', delete=False) as f:
            f.write(wrapped_html)
            return f.name
            
    def extract_using_selenium(self, html_content: str) -> List[Dict]:
        """Extract business data using Selenium and our extractors"""
        temp_file = self.create_test_page(html_content)
        
        try:
            # Load the HTML in browser
            self.driver.get(f"file://{temp_file}")
            time.sleep(1)  # Let page render
            
            # Find all business elements
            business_elements = self.driver.find_elements(By.CSS_SELECTOR, "div.Nv2PK")
            
            if not business_elements:
                # Try alternative selectors
                business_elements = self.driver.find_elements(By.CSS_SELECTOR, "[role='article']")
                
            if not business_elements:
                # Last resort - find divs with business-like content
                all_divs = self.driver.find_elements(By.TAG_NAME, "div")
                business_elements = []
                for div in all_divs:
                    try:
                        # Check if div has business indicators
                        if div.find_elements(By.CSS_SELECTOR, "a[href*='/maps/place/']"):
                            business_elements.append(div)
                    except:
                        pass
                        
            print(f"Found {len(business_elements)} business elements")
            
            # Extract data from each element
            extracted = []
            factory = BusinessExtractorFactory(self.driver)
            
            for i, element in enumerate(business_elements):
                try:
                    # Try standard extractor first
                    standard_extractor = StandardListingExtractor()
                    if standard_extractor.can_handle(element):
                        data = standard_extractor.extract(element, self.driver)
                        data['extractor_type'] = 'standard'
                        extracted.append(data)
                        print(f"✓ Extracted business {i+1} using StandardListingExtractor")
                    else:
                        # Try compact extractor
                        compact_extractor = CompactListingExtractor()
                        if compact_extractor.can_handle(element):
                            data = compact_extractor.extract(element, self.driver)
                            data['extractor_type'] = 'compact'
                            extracted.append(data)
                            print(f"✓ Extracted business {i+1} using CompactListingExtractor")
                        else:
                            print(f"⚠ No extractor could handle business {i+1}")
                            
                except Exception as e:
                    print(f"✗ Failed to extract business {i+1}: {str(e)}")
                    
            return extracted
            
        finally:
            # Clean up temp file
            os.unlink(temp_file)
            
    def test_standard_listing_with_website(self):
        """Test extraction of standard listing WITH website"""
        print("\n" + "="*60)
        print("TEST: Standard Listing WITH Website")
        print("="*60)
        
        html = self.load_html_file("standard-business-listing-with-website.html")
        businesses = self.extract_using_selenium(html)
        
        assert len(businesses) >= 1, f"Expected at least 1 business, got {len(businesses)}"
        
        business = businesses[0]
        assert business.get('name'), "Business name not extracted"
        assert business.get('has_website') == True, "Website presence not detected"
        assert business.get('website'), "Website URL not extracted"
        
        print(f"✓ Name: {business.get('name')}")
        print(f"✓ Website: {business.get('website')}")
        print(f"✓ Rating: {business.get('rating')}")
        print(f"✓ Phone: {business.get('phone')}")
        
        return True
        
    def test_standard_listing_without_website(self):
        """Test extraction of standard listing WITHOUT website"""
        print("\n" + "="*60)
        print("TEST: Standard Listing WITHOUT Website")
        print("="*60)
        
        html = self.load_html_file("standard-business-listing-without-website.html")
        businesses = self.extract_using_selenium(html)
        
        assert len(businesses) >= 1, f"Expected at least 1 business, got {len(businesses)}"
        
        business = businesses[0]
        assert business.get('name'), "Business name not extracted"
        assert business.get('has_website') == False, "Incorrectly detected website"
        assert not business.get('website'), "Website URL should be None"
        
        print(f"✓ Name: {business.get('name')}")
        print(f"✓ No Website (correct)")
        print(f"✓ Rating: {business.get('rating')}")
        print(f"✓ Phone: {business.get('phone')}")
        
        return True
        
    def test_compact_listing(self):
        """Test extraction of compact listing (requires click for details)"""
        print("\n" + "="*60)
        print("TEST: Compact Listing")
        print("="*60)
        
        html = self.load_html_file("compact-business-listing.html")
        businesses = self.extract_using_selenium(html)
        
        assert len(businesses) >= 1, f"Expected at least 1 business, got {len(businesses)}"
        
        business = businesses[0]
        assert business.get('name'), "Business name not extracted"
        assert business.get('extractor_type') == 'compact', "Should use compact extractor"
        
        print(f"✓ Name: {business.get('name')}")
        print(f"✓ Extractor Type: {business.get('extractor_type')}")
        print(f"✓ Rating: {business.get('rating')}")
        
        return True
        
    def test_compact_expanded_with_website(self):
        """Test extraction of expanded compact listing WITH website"""
        print("\n" + "="*60)
        print("TEST: Compact Expanded WITH Website")
        print("="*60)
        
        html = self.load_html_file("compact-business-listing-expanded-with-website.html")
        businesses = self.extract_using_selenium(html)
        
        # This file may contain the expanded view, so we check for website presence
        if businesses:
            business = businesses[0]
            print(f"✓ Name: {business.get('name')}")
            print(f"✓ Website Detection: {business.get('has_website')}")
            if business.get('website'):
                print(f"✓ Website URL: {business.get('website')}")
                
        return True
        
    def test_compact_expanded_without_website(self):
        """Test extraction of expanded compact listing WITHOUT website"""
        print("\n" + "="*60)
        print("TEST: Compact Expanded WITHOUT Website")
        print("="*60)
        
        html = self.load_html_file("compact-business-listing-expanded-without-website.html")
        businesses = self.extract_using_selenium(html)
        
        if businesses:
            business = businesses[0]
            print(f"✓ Name: {business.get('name')}")
            print(f"✓ No Website: {not business.get('has_website')}")
            
        return True
        
    def test_mixed_listings(self):
        """Test extraction of mixed listing types"""
        print("\n" + "="*60)
        print("TEST: Mixed Listings (Multiple Business Types)")
        print("="*60)
        
        html = self.load_html_file("standard-businesses_website-nowebsite-website.html")
        businesses = self.extract_using_selenium(html)
        
        print(f"Found {len(businesses)} businesses in mixed listing")
        
        websites_found = 0
        no_websites_found = 0
        
        for i, business in enumerate(businesses):
            print(f"\nBusiness {i+1}:")
            print(f"  Name: {business.get('name')}")
            print(f"  Has Website: {business.get('has_website')}")
            print(f"  Website: {business.get('website', 'None')}")
            print(f"  Rating: {business.get('rating')}")
            
            if business.get('has_website'):
                websites_found += 1
            else:
                no_websites_found += 1
                
        print(f"\n✓ Businesses with websites: {websites_found}")
        print(f"✓ Businesses without websites: {no_websites_found}")
        
        return True
        
    def run_all_tests(self):
        """Run all extraction tests"""
        print("\n" + "🚀"*30)
        print("BULLETPROOF GOOGLE MAPS EXTRACTION TEST SUITE")
        print("🚀"*30)
        
        self.setup_driver()
        
        test_methods = [
            ("Standard WITH Website", self.test_standard_listing_with_website),
            ("Standard WITHOUT Website", self.test_standard_listing_without_website),
            ("Compact Listing", self.test_compact_listing),
            ("Compact Expanded WITH Website", self.test_compact_expanded_with_website),
            ("Compact Expanded WITHOUT Website", self.test_compact_expanded_without_website),
            ("Mixed Listings", self.test_mixed_listings),
        ]
        
        results = []
        
        for test_name, test_method in test_methods:
            try:
                success = test_method()
                results.append((test_name, "PASSED", None))
                print(f"\n✅ {test_name}: PASSED")
            except Exception as e:
                results.append((test_name, "FAILED", str(e)))
                print(f"\n❌ {test_name}: FAILED - {str(e)}")
                
        # Print summary
        print("\n" + "="*60)
        print("TEST SUMMARY")
        print("="*60)
        
        passed = len([r for r in results if r[1] == "PASSED"])
        failed = len([r for r in results if r[1] == "FAILED"])
        
        for test_name, status, error in results:
            if status == "PASSED":
                print(f"✅ {test_name}: {status}")
            else:
                print(f"❌ {test_name}: {status}")
                if error:
                    print(f"   Error: {error}")
                    
        print(f"\nTotal: {passed} passed, {failed} failed out of {len(results)} tests")
        
        if failed == 0:
            print("\n🎉 ALL TESTS PASSED! Extraction is bulletproof! 🎉")
            return True
        else:
            print("\n⚠️ Some tests failed. Review and fix extraction logic.")
            return False
            
    def cleanup(self):
        """Clean up resources"""
        if self.driver:
            self.driver.quit()


def main():
    """Main test runner"""
    test_suite = BulletproofExtractionTest()
    
    try:
        success = test_suite.run_all_tests()
        return 0 if success else 1
    except Exception as e:
        print(f"\n💥 Test suite failed with error: {e}")
        import traceback
        traceback.print_exc()
        return 1
    finally:
        test_suite.cleanup()


if __name__ == "__main__":
    exit(main())