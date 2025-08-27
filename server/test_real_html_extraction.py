"""
Tests using real HTML structures from Google Maps to verify website detection.
Tests both standard listings (painters) and compact listings (barber shops).
"""

import unittest
from unittest.mock import Mock, MagicMock, patch
from selenium.common.exceptions import NoSuchElementException
from business_extractor import (
    StandardListingExtractor,
    CompactListingExtractor,
    BusinessExtractorFactory
)


class MockElement:
    """Mock element that simulates real HTML structure"""
    
    def __init__(self, html_structure):
        self.html_structure = html_structure
        self.found_elements = {}
    
    def find_element(self, by, selector):
        """Simulate finding elements based on CSS selector"""
        if selector in self.html_structure:
            element = Mock()
            element.text = self.html_structure[selector].get('text', '')
            element.get_attribute = Mock(return_value=self.html_structure[selector].get('attribute', ''))
            return element
        raise NoSuchElementException(f"No element found for selector: {selector}")
    
    def find_elements(self, by, selector):
        """Simulate finding multiple elements"""
        if selector in self.html_structure:
            return self.html_structure[selector]
        return []


class TestRealWorldBarberShopListing(unittest.TestCase):
    """Test extraction from real barber shop HTML structure"""
    
    def setUp(self):
        # Simulate the actual barber shop HTML structure
        self.barber_html = {
            # Name element
            ".qBF1Pd.fontHeadlineSmall": {
                "text": "Ascension Barbershop",
                "attribute": None
            },
            # Rating/reviews
            "span.ZkP5Je[aria-label]": {
                "text": "4.9",
                "attribute": "4.9 stars 560 Reviews"
            },
            # NO Website button in list view (key distinction!)
            # "a[data-value='Website']": NOT PRESENT
            
            # Compact container indicator
            ".qty3Ue": {
                "text": "",
                "attribute": None
            },
            # Link to business
            "a.hfpxzc": {
                "text": "",
                "attribute": "https://www.google.com/maps/place/Ascension+Barbershop/..."
            }
        }
        
        # Simulate what's found when clicking into the business
        self.barber_detail_html = {
            # Website info found in detail view
            "a.CsEnBe[href*='://']": {
                "text": "ascensionbarbershop.com",
                "attribute": "https://ascensionbarbershop.com/"
            },
            # Alternative website element
            ".Io6YTe.fontBodyMedium": {
                "text": "ascensionbarbershop.com",
                "attribute": None
            }
        }
    
    def test_barber_shop_detected_as_compact_listing(self):
        """Test that barber shop is correctly identified as compact listing"""
        element = MockElement(self.barber_html)
        
        standard_extractor = StandardListingExtractor()
        compact_extractor = CompactListingExtractor()
        
        # Standard extractor should NOT handle this (no Website button)
        self.assertFalse(standard_extractor.can_handle(element))
        
        # Compact extractor SHOULD handle this (has Book button, no Website)
        self.assertTrue(compact_extractor.can_handle(element))
    
    def test_barber_shop_extraction_without_click_through(self):
        """Test barber shop extraction when click-through is disabled"""
        element = MockElement(self.barber_html)
        extractor = CompactListingExtractor()
        
        details = extractor.extract(element, driver=None)
        
        # Should extract basic info
        self.assertEqual(details['name'], "Ascension Barbershop")
        self.assertEqual(details['rating'], "4.9")
        self.assertEqual(details['reviews'], "560")
        
        # Should NOT have website (needs click-through)
        self.assertIsNone(details['website'])
        self.assertFalse(details['has_website'])
        
        # Should flag that click-through is needed
        self.assertTrue(details.get('_needs_click_check', False))
    
    @patch('time.sleep')
    def test_barber_shop_website_found_via_click_through(self, mock_sleep):
        """Test that clicking into barber shop finds the website"""
        element = MockElement(self.barber_html)
        
        # Mock driver that will find website in detail view
        driver = Mock()
        driver.current_url = "https://maps.google.com/search"
        
        # When clicked, driver finds the detail page elements
        def driver_find_element(by, selector):
            detail_element = MockElement(self.barber_detail_html)
            return detail_element.find_element(by, selector)
        
        driver.find_element.side_effect = driver_find_element
        
        # Mock WebDriverWait
        mock_wait = Mock()
        mock_wait.until = Mock()
        
        with patch('selenium.webdriver.support.wait.WebDriverWait', return_value=mock_wait):
            extractor = CompactListingExtractor()
            details = extractor.extract(element, driver=driver)
        
        # Should have found website via click-through
        self.assertEqual(details['website'], "https://ascensionbarbershop.com/")
        self.assertTrue(details['has_website'])
        
        # Verify click and navigation happened
        driver.execute_script.assert_called()  # Click into business
        driver.back.assert_called()  # Navigate back to list


class TestRealWorldPainterListing(unittest.TestCase):
    """Test extraction from real painter HTML structure"""
    
    def setUp(self):
        # Simulate the actual painter HTML structure
        self.painter_html = {
            # Name element
            ".qBF1Pd.fontHeadlineSmall": {
                "text": "CertaPro Painters of Omaha, NE",
                "attribute": None
            },
            # Rating/reviews
            "span.ZkP5Je[aria-label]": {
                "text": "4.9",
                "attribute": "4.9 stars 373 Reviews"
            },
            # Phone
            "span.UsdlK": {
                "text": "(402) 493-5358",
                "attribute": None
            },
            # Website button PRESENT in list view (key distinction!)
            "a[data-value='Website']": {
                "text": "Website",
                "attribute": "https://www.certapro.com/omaha"
            },
            # Action container with buttons
            ".Rwjeuc": {
                "text": "",
                "attribute": None
            },
            # Link to business
            "a.hfpxzc": {
                "text": "",
                "attribute": "https://www.google.com/maps/place/CertaPro+Painters..."
            }
        }
    
    def test_painter_detected_as_standard_listing(self):
        """Test that painter is correctly identified as standard listing"""
        element = MockElement(self.painter_html)
        
        standard_extractor = StandardListingExtractor()
        compact_extractor = CompactListingExtractor()
        
        # Standard extractor SHOULD handle this (has Website button)
        self.assertTrue(standard_extractor.can_handle(element))
        
        # Compact extractor should NOT handle this
        self.assertFalse(compact_extractor.can_handle(element))
    
    def test_painter_website_extracted_directly(self):
        """Test that painter website is extracted without click-through"""
        element = MockElement(self.painter_html)
        extractor = StandardListingExtractor()
        
        # No driver needed - website visible in list
        details = extractor.extract(element, driver=None)
        
        # Should extract all info including website
        self.assertEqual(details['name'], "CertaPro Painters of Omaha, NE")
        self.assertEqual(details['rating'], "4.9")
        self.assertEqual(details['reviews'], "373")
        self.assertEqual(details['phone'], "(402) 493-5358")
        
        # Should have website WITHOUT click-through
        self.assertEqual(details['website'], "https://www.certapro.com/omaha")
        self.assertTrue(details['has_website'])
    
    def test_painter_without_website_button(self):
        """Test painter-style listing that has no website"""
        # Painter with no website button
        painter_no_website = dict(self.painter_html)
        del painter_no_website["a[data-value='Website']"]
        
        element = MockElement(painter_no_website)
        extractor = StandardListingExtractor()
        
        details = extractor.extract(element, driver=None)
        
        # Should extract info but no website
        self.assertEqual(details['name'], "CertaPro Painters of Omaha, NE")
        self.assertIsNone(details['website'])
        self.assertFalse(details['has_website'])


class TestFactorySelection(unittest.TestCase):
    """Test that factory correctly selects extractor based on HTML structure"""
    
    def test_factory_selects_correct_extractor_for_barber(self):
        """Test factory chooses CompactListingExtractor for barber shop HTML"""
        barber_html = {
            ".qBF1Pd.fontHeadlineSmall": {"text": "Test Barber"},
            ".qty3Ue": {"text": ""}
            # No Website button, no Rwjeuc container
        }
        
        element = MockElement(barber_html)
        factory = BusinessExtractorFactory()
        
        # Should use CompactListingExtractor
        for extractor in factory.extractors:
            if isinstance(extractor, CompactListingExtractor):
                self.assertTrue(extractor.can_handle(element))
            elif isinstance(extractor, StandardListingExtractor):
                self.assertFalse(extractor.can_handle(element))
    
    def test_factory_selects_correct_extractor_for_painter(self):
        """Test factory chooses StandardListingExtractor for painter HTML"""
        painter_html = {
            ".qBF1Pd.fontHeadlineSmall": {"text": "Test Painter"},
            "a[data-value='Website']": {"text": "Website", "attribute": "https://example.com"},
            ".Rwjeuc": {"text": ""}
        }
        
        element = MockElement(painter_html)
        factory = BusinessExtractorFactory()
        
        # Should use StandardListingExtractor
        for extractor in factory.extractors:
            if isinstance(extractor, StandardListingExtractor):
                self.assertTrue(extractor.can_handle(element))
            elif isinstance(extractor, CompactListingExtractor):
                self.assertFalse(extractor.can_handle(element))


class TestWebsiteDetectionStrategies(unittest.TestCase):
    """Test different website detection strategies for each type"""
    
    def test_standard_listing_website_detection_methods(self):
        """Test all ways standard listings show websites"""
        
        # Method 1: Website button with href
        html_with_website = {
            ".qBF1Pd.fontHeadlineSmall": {"text": "Business Name"},
            "a[data-value='Website']": {
                "text": "Website",
                "attribute": "https://businesswebsite.com"
            }
        }
        
        element = MockElement(html_with_website)
        extractor = StandardListingExtractor()
        details = extractor.extract(element)
        
        self.assertTrue(details['has_website'])
        self.assertEqual(details['website'], "https://businesswebsite.com")
    
    @patch('time.sleep')
    def test_compact_listing_website_detection_methods(self, mock_sleep):
        """Test all ways compact listings reveal websites via click-through"""
        
        list_html = {
            ".qBF1Pd.fontHeadlineSmall": {"text": "Compact Business"},
            ".qty3Ue": {"text": ""},
            "a.hfpxzc": {"attribute": "https://maps.google.com/business"}
        }
        
        element = MockElement(list_html)
        driver = Mock()
        
        # Test Method 1: CsEnBe link
        detail_html_method1 = {
            "a.CsEnBe[href*='://']": {
                "attribute": "https://compactbusiness.com"
            }
        }
        
        driver.find_element.return_value = MockElement(detail_html_method1).find_element(
            None, "a.CsEnBe[href*='://']"
        )
        
        mock_wait = Mock()
        with patch('selenium.webdriver.support.wait.WebDriverWait', return_value=mock_wait):
            extractor = CompactListingExtractor()
            details = extractor.extract(element, driver=driver)
        
        self.assertTrue(details['has_website'])
        self.assertEqual(details['website'], "https://compactbusiness.com")
        
        # Test Method 2: Io6YTe element with domain text
        driver.reset_mock()
        driver.find_element.side_effect = [
            Mock(get_attribute=Mock(return_value="https://maps.google.com/business")),  # hfpxzc link
            NoSuchElementException(),  # No CsEnBe
            Mock(text="businessdomain.com")  # Io6YTe with domain
        ]
        
        details = extractor._check_website_via_click(element, driver, "Test Business")
        self.assertEqual(details, "https://businessdomain.com")


class TestEdgeCases(unittest.TestCase):
    """Test edge cases and error handling"""
    
    def test_malformed_html_structure(self):
        """Test handling of malformed or unexpected HTML"""
        malformed_html = {
            # Missing expected elements
        }
        
        element = MockElement(malformed_html)
        factory = BusinessExtractorFactory()
        
        # Should not crash, should return basic structure
        details = factory.extract(element)
        self.assertIsNotNone(details)
        self.assertFalse(details.get('has_website', False))
    
    def test_sponsored_listing_with_different_structure(self):
        """Test sponsored listings which might have different structure"""
        sponsored_html = {
            ".qBF1Pd.fontHeadlineSmall": {"text": "Sponsored Business"},
            ".OcdnDb": {"text": "Sponsored"},  # Sponsored indicator
            "a[data-value='Website']": {
                "attribute": "/aclk?sa=L&ai=..."  # Google redirect URL
            }
        }
        
        element = MockElement(sponsored_html)
        extractor = StandardListingExtractor()
        details = extractor.extract(element)
        
        # Should still detect as having website even with redirect URL
        self.assertTrue(details['has_website'])
        self.assertIn("/aclk", details['website'])


if __name__ == '__main__':
    unittest.main()