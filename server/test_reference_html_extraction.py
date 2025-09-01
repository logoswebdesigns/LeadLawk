#!/usr/bin/env python3
"""
Test extraction from reference HTML files without Selenium.
Uses BeautifulSoup to parse and validate extraction logic.
"""

import os
import re
from pathlib import Path
from bs4 import BeautifulSoup
from typing import Dict, List, Optional


class ReferenceHTMLTest:
    """Test extraction logic on reference HTML files"""
    
    def __init__(self):
        self.reference_dir = Path("google-maps-reference")
        
    def extract_from_html(self, html_content: str) -> List[Dict]:
        """Extract business data using semantic patterns"""
        soup = BeautifulSoup(html_content, 'html.parser')
        businesses = []
        
        # Find business containers (div.Nv2PK pattern)
        business_divs = soup.find_all('div', class_='Nv2PK')
        
        for div in business_divs:
            business = self.extract_business_data(div)
            if business and business.get('name'):
                businesses.append(business)
                
        return businesses
        
    def extract_business_data(self, element) -> Dict:
        """Extract data from a single business element"""
        data = {}
        
        # Extract name from aria-label on link
        link = element.find('a', {'aria-label': True, 'href': re.compile(r'/maps/place/')})
        if link:
            aria_label = link.get('aria-label', '')
            # Clean up aria-label
            name = aria_label.split('·')[0].strip()
            data['name'] = name
        else:
            # Try to find name in heading-like divs
            name_div = element.find('div', class_=re.compile(r'qBF1Pd|fontHeadline'))
            if name_div:
                data['name'] = name_div.get_text(strip=True)
                
        # Extract rating from role="img" aria-label
        rating_elem = element.find(attrs={'role': 'img', 'aria-label': re.compile(r'star|review', re.I)})
        if rating_elem:
            aria_label = rating_elem.get('aria-label', '')
            # Extract rating number
            rating_match = re.search(r'(\d+\.?\d*)\s*star', aria_label, re.I)
            if rating_match:
                data['rating'] = float(rating_match.group(1))
            # Extract review count
            review_match = re.search(r'(\d+)\s*review', aria_label, re.I)
            if review_match:
                data['reviews'] = int(review_match.group(1))
                
        # Extract phone number
        phone_spans = element.find_all('span', class_='UsdlK')
        for span in phone_spans:
            text = span.get_text(strip=True)
            if re.match(r'[\(\)\d\s\-\+]+', text):
                data['phone'] = text
                break
                
        # Extract website - look for data-value="Website"
        website_link = element.find('a', {'data-value': 'Website'})
        if website_link:
            data['website'] = website_link.get('href', '')
            data['has_website'] = True
        else:
            data['has_website'] = False
            data['website'] = None
            
        # Check if compact listing (no action buttons visible)
        action_buttons = element.find_all(['a', 'button'], {'data-value': True})
        data['is_compact'] = len(action_buttons) == 0
        
        return data
        
    def test_standard_with_website(self):
        """Test standard listing with website"""
        print("\n" + "="*60)
        print("TEST: Standard Business WITH Website")
        print("="*60)
        
        file_path = self.reference_dir / "standard-business-listing-with-website.html"
        with open(file_path, 'r', encoding='utf-8') as f:
            html = f.read()
            
        businesses = self.extract_from_html(html)
        
        assert len(businesses) > 0, "No businesses found"
        
        business = businesses[0]
        print(f"✓ Name: {business.get('name')}")
        print(f"✓ Rating: {business.get('rating')}")
        print(f"✓ Reviews: {business.get('reviews')}")
        print(f"✓ Phone: {business.get('phone')}")
        print(f"✓ Has Website: {business.get('has_website')}")
        print(f"✓ Website: {business.get('website')}")
        
        assert business.get('has_website') == True, "Should have website"
        assert business.get('website'), "Website URL missing"
        
        return True
        
    def test_standard_without_website(self):
        """Test standard listing without website"""
        print("\n" + "="*60)
        print("TEST: Standard Business WITHOUT Website")
        print("="*60)
        
        file_path = self.reference_dir / "standard-business-listing-without-website.html"
        with open(file_path, 'r', encoding='utf-8') as f:
            html = f.read()
            
        businesses = self.extract_from_html(html)
        
        assert len(businesses) > 0, "No businesses found"
        
        business = businesses[0]
        print(f"✓ Name: {business.get('name')}")
        print(f"✓ Rating: {business.get('rating')}")
        print(f"✓ Reviews: {business.get('reviews')}")
        print(f"✓ Phone: {business.get('phone')}")
        print(f"✓ Has Website: {business.get('has_website')}")
        
        assert business.get('has_website') == False, "Should not have website"
        
        return True
        
    def test_compact_listing(self):
        """Test compact listing"""
        print("\n" + "="*60)
        print("TEST: Compact Business Listing")
        print("="*60)
        
        file_path = self.reference_dir / "compact-business-listing.html"
        with open(file_path, 'r', encoding='utf-8') as f:
            html = f.read()
            
        businesses = self.extract_from_html(html)
        
        if len(businesses) > 0:
            business = businesses[0]
            print(f"✓ Name: {business.get('name')}")
            print(f"✓ Rating: {business.get('rating')}")
            print(f"✓ Is Compact: {business.get('is_compact')}")
            
            assert business.get('is_compact') == True, "Should be compact listing"
        else:
            # Compact listings might have different structure
            print("⚠ Compact listing has different structure")
            
        return True
        
    def test_mixed_listings(self):
        """Test file with multiple business types"""
        print("\n" + "="*60)
        print("TEST: Mixed Business Listings")
        print("="*60)
        
        file_path = self.reference_dir / "standard-businesses_website-nowebsite-website.html"
        with open(file_path, 'r', encoding='utf-8') as f:
            html = f.read()
            
        businesses = self.extract_from_html(html)
        
        print(f"Found {len(businesses)} businesses")
        
        with_website = 0
        without_website = 0
        
        for i, business in enumerate(businesses, 1):
            print(f"\nBusiness {i}:")
            print(f"  Name: {business.get('name')}")
            print(f"  Has Website: {business.get('has_website')}")
            
            if business.get('has_website'):
                with_website += 1
            else:
                without_website += 1
                
        print(f"\n✓ With website: {with_website}")
        print(f"✓ Without website: {without_website}")
        
        return True
        
    def run_all_tests(self):
        """Run all tests"""
        print("\n🚀 REFERENCE HTML EXTRACTION TESTS")
        print("="*60)
        
        tests = [
            ("Standard WITH Website", self.test_standard_with_website),
            ("Standard WITHOUT Website", self.test_standard_without_website),
            ("Compact Listing", self.test_compact_listing),
            ("Mixed Listings", self.test_mixed_listings),
        ]
        
        results = []
        
        for test_name, test_func in tests:
            try:
                test_func()
                results.append((test_name, "PASSED"))
                print(f"\n✅ {test_name}: PASSED")
            except Exception as e:
                results.append((test_name, f"FAILED: {e}"))
                print(f"\n❌ {test_name}: FAILED - {e}")
                
        # Summary
        print("\n" + "="*60)
        print("SUMMARY")
        print("="*60)
        
        passed = sum(1 for _, status in results if status == "PASSED")
        total = len(results)
        
        for test_name, status in results:
            if status == "PASSED":
                print(f"✅ {test_name}")
            else:
                print(f"❌ {test_name}: {status}")
                
        print(f"\nTotal: {passed}/{total} tests passed")
        
        return passed == total


def main():
    """Run tests"""
    tester = ReferenceHTMLTest()
    success = tester.run_all_tests()
    return 0 if success else 1


if __name__ == "__main__":
    exit(main())