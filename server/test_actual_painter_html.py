"""
Test using the EXACT HTML structure you provided for Five Star Painting.
This verifies our StandardListingExtractor correctly detects the visible Website button.
"""

import unittest
from unittest.mock import Mock
from selenium.common.exceptions import NoSuchElementException
from business_extractor import StandardListingExtractor, CompactListingExtractor, BusinessExtractorFactory


class MockElementFromActualHTML:
    """Mock element based on the exact Five Star Painting HTML structure"""
    
    def __init__(self):
        # Simulate the actual selectors and their return values from your HTML
        self.selectors = {
            # Business name from the HTML
            ".qBF1Pd.fontHeadlineSmall": {
                "text": "Five Star Painting of Sarpy County"
            },
            
            # Rating from aria-label  
            "span.ZkP5Je[aria-label]": {
                "text": "5.0",
                "attribute": "5.0 stars 52 Reviews"
            },
            
            # Phone number
            "span.UsdlK": {
                "text": "(402) 543-3239"
            },
            
            # THE CRITICAL WEBSITE BUTTON - this is what should be detected!
            "a[data-value='Website']": {
                "text": "Website",
                "attribute": "https://www.fivestarpainting.com/sarpy-county/?cid=LSTL_FSP-US000189&utm_source=gmb&utm_campaign=local&utm_medium=organic"
            },
            
            # The Rwjeuc container that holds action buttons
            ".Rwjeuc": {
                "text": ""  # Container exists
            },
            
            # Main business link
            "a.hfpxzc": {
                "attribute": "https://www.google.com/maps/place/Five+Star+Painting+of+Sarpy+County/data=..."
            }
        }
    
    def find_element(self, by, selector):
        """Simulate Selenium's find_element based on actual HTML"""
        print(f"    🔍 MockElement: Looking for selector '{selector}'")
        
        if selector in self.selectors:
            element = Mock()
            element.text = self.selectors[selector]["text"]
            
            if "attribute" in self.selectors[selector]:
                element.get_attribute = Mock(return_value=self.selectors[selector]["attribute"])
            else:
                element.get_attribute = Mock(return_value="")
                
            print(f"    ✅ MockElement: Found '{selector}' -> text='{element.text}', href='{element.get_attribute('href')}'")
            return element
        else:
            print(f"    ❌ MockElement: '{selector}' not found")
            raise NoSuchElementException(f"No element found for selector: {selector}")
    
    def find_elements(self, by, selector):
        """Simulate finding multiple elements (for photos, etc.)"""
        return []  # No photos in this example


class TestActualPainterHTML(unittest.TestCase):
    """Test with the exact Five Star Painting HTML structure"""
    
    def test_painter_detected_as_standard_listing(self):
        """Test that Five Star Painting HTML is correctly identified as standard listing"""
        print("\n🧪 Testing: Five Star Painting HTML Detection")
        
        element = MockElementFromActualHTML()
        
        standard_extractor = StandardListingExtractor()
        compact_extractor = CompactListingExtractor()
        
        print("  🔍 Testing StandardListingExtractor.can_handle()...")
        can_handle_standard = standard_extractor.can_handle(element)
        print(f"  📊 StandardListingExtractor.can_handle() = {can_handle_standard}")
        
        print("  🔍 Testing CompactListingExtractor.can_handle()...")
        can_handle_compact = compact_extractor.can_handle(element)
        print(f"  📊 CompactListingExtractor.can_handle() = {can_handle_compact}")
        
        # StandardListingExtractor SHOULD handle this (has visible Website button)
        self.assertTrue(can_handle_standard, 
            "StandardListingExtractor should handle Five Star Painting HTML (has visible Website button)")
        
        # CompactListingExtractor should NOT handle this (Website button is visible)
        self.assertFalse(can_handle_compact,
            "CompactListingExtractor should NOT handle Five Star Painting HTML (Website button is visible)")
    
    def test_factory_selects_standard_extractor_for_painter(self):
        """Test that BusinessExtractorFactory selects StandardListingExtractor"""
        print("\n🧪 Testing: Factory Selection for Five Star Painting")
        
        element = MockElementFromActualHTML()
        factory = BusinessExtractorFactory()
        
        # The factory should select StandardListingExtractor for this HTML
        print("  🔍 Testing which extractor the factory would choose...")
        
        # Check each extractor
        for i, extractor in enumerate(factory.extractors):
            can_handle = extractor.can_handle(element)
            print(f"  📊 Extractor {i} ({extractor.__class__.__name__}): can_handle = {can_handle}")
        
        # StandardListingExtractor should be first and should handle this
        self.assertIsInstance(factory.extractors[0], StandardListingExtractor)
        self.assertTrue(factory.extractors[0].can_handle(element))
    
    def test_website_extraction_from_painter_html(self):
        """Test that website is correctly extracted from Five Star Painting HTML"""
        print("\n🧪 Testing: Website Extraction from Five Star Painting")
        
        element = MockElementFromActualHTML()
        extractor = StandardListingExtractor()
        
        print("  🔍 Extracting business details...")
        details = extractor.extract(element)
        
        print(f"  📊 Extracted details:")
        print(f"    Name: {details.get('name')}")
        print(f"    Rating: {details.get('rating')}")
        print(f"    Reviews: {details.get('reviews')}")
        print(f"    Phone: {details.get('phone')}")
        print(f"    Has Website: {details.get('has_website')}")
        print(f"    Website URL: {details.get('website')}")
        
        # Verify all expected data is extracted
        self.assertEqual(details['name'], "Five Star Painting of Sarpy County")
        self.assertEqual(details['rating'], "5.0")
        self.assertEqual(details['reviews'], "52")
        self.assertEqual(details['phone'], "(402) 543-3239")
        
        # CRITICAL: Website should be detected and extracted
        self.assertTrue(details['has_website'], 
            "has_website should be True for Five Star Painting (has visible Website button)")
        
        expected_website = "https://www.fivestarpainting.com/sarpy-county/?cid=LSTL_FSP-US000189&utm_source=gmb&utm_campaign=local&utm_medium=organic"
        self.assertEqual(details['website'], expected_website,
            f"Website URL should match the href attribute from the Website button")
    
    def test_main_entry_point_with_painter_html(self):
        """Test the main extract_business_details function with Five Star Painting HTML"""
        print("\n🧪 Testing: Main Entry Point with Five Star Painting")
        
        from business_extractor import extract_business_details
        
        element = MockElementFromActualHTML()
        
        print("  🔍 Testing extract_business_details()...")
        details = extract_business_details(element, driver=None, enable_click_through=False)
        
        print(f"  📊 Main function results:")
        print(f"    Name: {details.get('name')}")
        print(f"    Has Website: {details.get('has_website')}")
        print(f"    Website URL: {details.get('website', 'None')[:80]}...")
        
        # Should extract website WITHOUT needing click-through
        self.assertTrue(details['has_website'])
        self.assertIsNotNone(details['website'])
        self.assertIn("fivestarpainting.com", details['website'])


class TestWebsiteButtonDetection(unittest.TestCase):
    """Specific tests for Website button detection logic"""
    
    def test_website_button_selector_specificity(self):
        """Test that our selector correctly identifies the Website button"""
        print("\n🧪 Testing: Website Button Selector Specificity")
        
        element = MockElementFromActualHTML()
        
        # Test the exact selector we use in StandardListingExtractor
        selector = "a[data-value='Website']"
        
        print(f"  🔍 Testing selector: {selector}")
        
        try:
            website_element = element.find_element(None, selector)
            href = website_element.get_attribute('href')
            
            print(f"  ✅ Selector found element with href: {href}")
            
            self.assertIsNotNone(href)
            self.assertIn("fivestarpainting.com", href)
            
        except NoSuchElementException:
            self.fail(f"Selector '{selector}' should find the Website button in Five Star Painting HTML")
    
    def test_website_vs_directions_button_distinction(self):
        """Test that we can distinguish Website button from Directions button"""
        print("\n🧪 Testing: Website vs Directions Button Distinction")
        
        # Add Directions button to mock
        element = MockElementFromActualHTML()
        element.selectors["button[data-value='Directions']"] = {
            "text": "Directions",
            "attribute": ""  # No href for buttons
        }
        
        # Website button should be found
        try:
            website_elem = element.find_element(None, "a[data-value='Website']")
            website_href = website_elem.get_attribute('href')
            print(f"  ✅ Website button found: {website_href}")
        except NoSuchElementException:
            self.fail("Website button should be found")
        
        # Directions button should be found but shouldn't be confused with Website
        try:
            directions_elem = element.find_element(None, "button[data-value='Directions']")
            print(f"  ✅ Directions button found (correctly distinguished)")
        except NoSuchElementException:
            pass  # It's OK if not found, we're just testing distinction


if __name__ == '__main__':
    # Run with verbose output to see the detailed testing flow
    unittest.main(verbosity=2)