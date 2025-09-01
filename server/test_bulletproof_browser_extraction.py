#!/usr/bin/env python3
"""
End-to-end test of bulletproof extraction using actual browser automation.
Tests the complete extraction pipeline with Selenium and our enhanced extractors.
"""

import os
import time
from pathlib import Path
from typing import Dict, List
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.support.wait import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from business_extractor import StandardListingExtractor, CompactListingExtractor


class BulletproofBrowserTest:
    """Test extraction with real browser automation"""
    
    def __init__(self):
        self.driver = None
        self.reference_dir = Path("google-maps-reference")
        
    def setup_driver(self):
        """Setup Selenium driver"""
        options = Options()
        options.add_argument("--headless")
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-dev-shm-usage")
        options.add_argument("--window-size=1920,1080")
        
        # Use Docker's selenium-chrome service
        selenium_hub_url = "http://selenium-chrome:4444/wd/hub"
        self.driver = webdriver.Remote(command_executor=selenium_hub_url, options=options)
        
    def test_extraction_on_file(self, filename: str, expected_results: Dict):
        """Test extraction on a specific reference file"""
        print(f"\n{'='*60}")
        print(f"Testing: {filename}")
        print(f"{'='*60}")
        
        # Load HTML file
        file_path = self.reference_dir / filename
        with open(file_path, 'r', encoding='utf-8') as f:
            html_content = f.read()
            
        # Create a data URL to load HTML directly
        import base64
        html_b64 = base64.b64encode(html_content.encode()).decode()
        data_url = f"data:text/html;base64,{html_b64}"
        
        # Load in browser
        self.driver.get(data_url)
        time.sleep(2)  # Let page render
        
        # Find business elements
        business_elements = self.driver.find_elements(By.CSS_SELECTOR, "div.Nv2PK")
        print(f"Found {len(business_elements)} business elements")
        
        # Extract data using our extractors
        extracted_businesses = []
        standard_extractor = StandardListingExtractor()
        compact_extractor = CompactListingExtractor()
        
        for i, element in enumerate(business_elements):
            try:
                # Try standard extractor
                if standard_extractor.can_handle(element):
                    data = standard_extractor.extract(element, self.driver)
                    data['extractor_type'] = 'standard'
                    extracted_businesses.append(data)
                    print(f"  ✓ Business {i+1}: {data.get('name')} [Standard]")
                    print(f"    Website: {'Yes' if data.get('has_website') else 'No'}")
                # Try compact extractor
                elif compact_extractor.can_handle(element):
                    data = compact_extractor.extract(element, self.driver)
                    data['extractor_type'] = 'compact'
                    extracted_businesses.append(data)
                    print(f"  ✓ Business {i+1}: {data.get('name')} [Compact]")
                    print(f"    Website: {'Needs click-through' if data.get('_needs_click_check') else data.get('has_website')}")
                else:
                    print(f"  ✗ Business {i+1}: No extractor could handle")
            except Exception as e:
                print(f"  ✗ Business {i+1}: Extraction failed - {e}")
                
        # Validate results
        if 'min_businesses' in expected_results:
            assert len(extracted_businesses) >= expected_results['min_businesses'], \
                f"Expected at least {expected_results['min_businesses']} businesses, got {len(extracted_businesses)}"
                
        if 'has_website' in expected_results:
            for business in extracted_businesses:
                if expected_results['has_website']:
                    assert business.get('has_website') or business.get('_needs_click_check'), \
                        f"Business {business.get('name')} should have website indication"
                        
        print(f"\n✅ Test passed for {filename}")
        return True
        
    def run_all_tests(self):
        """Run all browser-based extraction tests"""
        print("\n🚀 BULLETPROOF BROWSER EXTRACTION TESTS")
        print("="*60)
        
        self.setup_driver()
        
        test_cases = [
            ("standard-business-listing-with-website.html", {
                'min_businesses': 1,
                'has_website': True
            }),
            ("standard-business-listing-without-website.html", {
                'min_businesses': 1,
                'has_website': False
            }),
            ("compact-business-listing.html", {
                'min_businesses': 1
            }),
            ("standard-businesses_website-nowebsite-website.html", {
                'min_businesses': 3
            }),
        ]
        
        results = []
        
        for filename, expected in test_cases:
            try:
                self.test_extraction_on_file(filename, expected)
                results.append((filename, "PASSED"))
            except Exception as e:
                results.append((filename, f"FAILED: {e}"))
                print(f"\n❌ Test failed for {filename}: {e}")
                
        # Summary
        print("\n" + "="*60)
        print("SUMMARY")
        print("="*60)
        
        passed = sum(1 for _, status in results if status == "PASSED")
        total = len(results)
        
        for filename, status in results:
            if status == "PASSED":
                print(f"✅ {filename}")
            else:
                print(f"❌ {filename}: {status}")
                
        print(f"\nTotal: {passed}/{total} tests passed")
        
        if passed == total:
            print("\n🎉 ALL BROWSER EXTRACTION TESTS PASSED! 🎉")
            print("Your Google Maps extraction is now BULLETPROOF!")
            
        return passed == total
        
    def cleanup(self):
        """Clean up resources"""
        if self.driver:
            self.driver.quit()


def main():
    """Run the test suite"""
    tester = BulletproofBrowserTest()
    
    try:
        success = tester.run_all_tests()
        return 0 if success else 1
    except Exception as e:
        print(f"\n💥 Test suite failed: {e}")
        import traceback
        traceback.print_exc()
        return 1
    finally:
        tester.cleanup()


if __name__ == "__main__":
    exit(main())