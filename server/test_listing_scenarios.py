#!/usr/bin/env python3
"""
Test script for all 4 business listing scenarios:
1. Standard listing with website
2. Standard listing without website  
3. Compact listing with website
4. Compact listing without website

This serves as a regression test when Google changes their DOM structure.
"""

import time
import json
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException
from business_extractor import BusinessExtractorFactory, StandardListingExtractor, CompactListingExtractor
from browser_setup import BrowserSetup

class ListingScenarioTester:
    """Test all 4 business listing scenarios"""
    
    def __init__(self):
        self.browser_setup = BrowserSetup(use_profile=False, headless=True)
        self.driver = None
        self.results = {
            "standard_with_website": [],
            "standard_without_website": [],
            "compact_with_website": [],
            "compact_without_website": []
        }
        self.test_passed = True
        
    def setup(self):
        """Initialize browser"""
        print("🌐 Setting up browser...")
        self.driver = self.browser_setup.setup_browser()
        if not self.driver:
            print("❌ Failed to setup browser")
            return False
        print("✅ Browser ready")
        return True
        
    def cleanup(self):
        """Clean up browser"""
        if self.browser_setup:
            self.browser_setup.close()
            
    def search_google_maps(self, query):
        """Perform a Google Maps search"""
        print(f"\n🔍 Searching for: {query}")
        
        # Navigate to Google Maps
        self.driver.get("https://www.google.com/maps")
        time.sleep(2)
        
        # Find and use the search box
        try:
            search_box = WebDriverWait(self.driver, 10).until(
                EC.presence_of_element_located((By.ID, "searchboxinput"))
            )
            search_box.clear()
            search_box.send_keys(query)
            
            # Click search button
            search_button = self.driver.find_element(By.ID, "searchbox-searchbutton")
            search_button.click()
            
            # Wait for results
            time.sleep(3)
            WebDriverWait(self.driver, 10).until(
                EC.presence_of_element_located((By.CSS_SELECTOR, "[role='feed'], [role='main'], [role='article']"))
            )
            print("✅ Search results loaded")
            return True
            
        except TimeoutException:
            print("❌ Failed to load search results")
            return False
            
    def analyze_listings(self, expected_type, limit=10):
        """Analyze business listings and categorize them"""
        print(f"\n📊 Analyzing {expected_type} listings...")
        
        # Find business elements
        business_elements = self.driver.find_elements(By.CSS_SELECTOR, "[role='article']")[:limit]
        
        if not business_elements:
            print("❌ No business listings found")
            return
            
        print(f"Found {len(business_elements)} business listings to analyze")
        
        factory = BusinessExtractorFactory(self.driver)
        
        for i, element in enumerate(business_elements, 1):
            try:
                # Scroll element into view
                self.driver.execute_script("arguments[0].scrollIntoView(true);", element)
                time.sleep(0.5)
                
                # Determine which extractor handles this
                is_standard = False
                is_compact = False
                
                standard_extractor = StandardListingExtractor()
                compact_extractor = CompactListingExtractor()
                
                if standard_extractor.can_handle(element):
                    is_standard = True
                    extractor_type = "STANDARD"
                elif compact_extractor.can_handle(element):
                    is_compact = True
                    extractor_type = "COMPACT"
                else:
                    extractor_type = "UNKNOWN"
                
                # Extract business details
                details = factory.extract(element)
                
                # Get business name for logging
                business_name = details.get('name', 'Unknown')
                has_website = details.get('has_website', False)
                website = details.get('website', None)
                
                # Categorize the result
                if is_standard and has_website:
                    category = "standard_with_website"
                    symbol = "🌐📋"
                elif is_standard and not has_website:
                    category = "standard_without_website"
                    symbol = "❌📋"
                elif is_compact and has_website:
                    category = "compact_with_website"
                    symbol = "🌐📦"
                elif is_compact and not has_website:
                    category = "compact_without_website"
                    symbol = "❌📦"
                else:
                    category = "unknown"
                    symbol = "❓"
                
                # Store result
                self.results[category].append({
                    "name": business_name,
                    "website": website,
                    "extractor": extractor_type
                })
                
                print(f"  {symbol} Business {i}: {business_name[:30]}")
                print(f"     Type: {extractor_type}, Has Website: {has_website}")
                if website:
                    print(f"     Website: {website[:50]}...")
                    
            except Exception as e:
                print(f"  ❌ Error analyzing business {i}: {str(e)[:100]}")
                continue
                
    def test_standard_listings(self):
        """Test standard listings (painters in Papillion)"""
        print("\n" + "="*60)
        print("📋 TESTING STANDARD LISTINGS (painter papillion)")
        print("="*60)
        
        if self.search_google_maps("painter papillion"):
            self.analyze_listings("STANDARD", limit=10)
            
            # Verify we found both types
            with_website = len(self.results["standard_with_website"])
            without_website = len(self.results["standard_without_website"])
            
            print(f"\n📊 Standard Listing Results:")
            print(f"  ✅ With website: {with_website}")
            print(f"  ❌ Without website: {without_website}")
            
            if with_website == 0:
                print("  ⚠️ WARNING: No standard listings with websites found!")
                self.test_passed = False
            if without_website == 0:
                print("  ⚠️ WARNING: No standard listings without websites found!")
                # This is less critical as some searches might have all businesses with websites
                
    def test_compact_listings(self):
        """Test compact listings (dentists in Papillion)"""
        print("\n" + "="*60)
        print("📦 TESTING COMPACT LISTINGS (dentist papillion)")
        print("="*60)
        
        if self.search_google_maps("dentist papillion"):
            self.analyze_listings("COMPACT", limit=10)
            
            # Verify we found both types
            with_website = len(self.results["compact_with_website"])
            without_website = len(self.results["compact_without_website"])
            
            print(f"\n📊 Compact Listing Results:")
            print(f"  ✅ With website: {with_website}")
            print(f"  ❌ Without website: {without_website}")
            
            if with_website == 0:
                print("  ⚠️ WARNING: No compact listings with websites found!")
                self.test_passed = False
            if without_website == 0:
                print("  ⚠️ WARNING: No compact listings without websites found!")
                # This is less critical
                
    def print_summary(self):
        """Print test summary"""
        print("\n" + "="*60)
        print("📈 TEST SUMMARY")
        print("="*60)
        
        total_tested = sum(len(v) for v in self.results.values())
        
        print(f"\nTotal businesses analyzed: {total_tested}")
        print("\nBreakdown by category:")
        
        for category, businesses in self.results.items():
            if businesses:
                category_display = category.replace("_", " ").title()
                print(f"\n{category_display}: {len(businesses)} businesses")
                for biz in businesses[:3]:  # Show first 3 examples
                    print(f"  • {biz['name'][:40]}")
                    if biz['website']:
                        print(f"    Website: {biz['website'][:50]}")
                        
        # Check for test success
        print("\n" + "="*60)
        print("🧪 TEST RESULTS")
        print("="*60)
        
        all_scenarios_found = all([
            len(self.results["standard_with_website"]) > 0,
            len(self.results["standard_without_website"]) > 0,
            len(self.results["compact_with_website"]) > 0,
            len(self.results["compact_without_website"]) > 0
        ])
        
        if all_scenarios_found:
            print("✅ SUCCESS: All 4 business listing scenarios detected!")
            print("  ✓ Standard listing with website")
            print("  ✓ Standard listing without website")
            print("  ✓ Compact listing with website")
            print("  ✓ Compact listing without website")
        else:
            print("⚠️ WARNING: Not all scenarios were detected:")
            if not self.results["standard_with_website"]:
                print("  ✗ Missing: Standard listing with website")
            if not self.results["standard_without_website"]:
                print("  ✗ Missing: Standard listing without website")
            if not self.results["compact_with_website"]:
                print("  ✗ Missing: Compact listing with website")
            if not self.results["compact_without_website"]:
                print("  ✗ Missing: Compact listing without website")
                
            print("\n⚠️ This might indicate:")
            print("  1. Google changed their DOM structure")
            print("  2. The extraction logic needs updating")
            print("  3. The search didn't return expected variety of businesses")
            
        return all_scenarios_found
        
    def run_all_tests(self):
        """Run all test scenarios"""
        print("\n🚀 Starting Business Listing Scenario Tests")
        print("This tests our ability to handle all 4 types of Google Maps listings")
        
        if not self.setup():
            return False
            
        try:
            # Test standard listings first
            self.test_standard_listings()
            
            # Test compact listings
            self.test_compact_listings()
            
            # Print summary
            success = self.print_summary()
            
            return success
            
        except Exception as e:
            print(f"\n❌ Test failed with error: {e}")
            return False
            
        finally:
            self.cleanup()
            
def main():
    """Main test runner"""
    tester = ListingScenarioTester()
    
    success = tester.run_all_tests()
    
    # Save results to file for analysis
    with open("test_listing_results.json", "w") as f:
        json.dump({
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
            "success": success,
            "results": tester.results
        }, f, indent=2)
        
    print(f"\n📁 Results saved to test_listing_results.json")
    
    # Exit with appropriate code
    exit(0 if success else 1)
    
if __name__ == "__main__":
    main()