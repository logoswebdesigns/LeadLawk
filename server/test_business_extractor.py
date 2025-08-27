"""
Comprehensive tests for business extraction from different Google Maps listing types.
Tests both standard listings (painters, restaurants) and compact listings (barber shops).
"""

import unittest
from unittest.mock import Mock, MagicMock, patch
from selenium.common.exceptions import NoSuchElementException
from business_extractor import (
    BusinessExtractor,
    StandardListingExtractor,
    CompactListingExtractor,
    BusinessExtractorFactory,
    extract_business_details
)


class TestStandardListingExtractor(unittest.TestCase):
    """Test extraction from standard business listings (e.g., painters)"""
    
    def setUp(self):
        self.extractor = StandardListingExtractor()
        
    def test_can_handle_standard_listing_with_website_button(self):
        """Test that standard listing with Website button is recognized"""
        # Mock element with Website button
        element = Mock()
        website_btn = Mock()
        element.find_element.return_value = website_btn
        
        self.assertTrue(self.extractor.can_handle(element))
        element.find_element.assert_called_with(unittest.mock.ANY, "a[data-value='Website']")
    
    def test_can_handle_standard_listing_with_action_container(self):
        """Test that standard listing with Rwjeuc container is recognized"""
        element = Mock()
        # First call fails (no Website button)
        # Second call succeeds (has Rwjeuc container)
        element.find_element.side_effect = [
            NoSuchElementException(),
            Mock()  # Action container found
        ]
        
        self.assertTrue(self.extractor.can_handle(element))
    
    def test_extract_standard_listing_with_website(self):
        """Test extraction from standard listing that has a website"""
        # Create mock element with all expected data
        element = Mock()
        
        # Setup name extraction
        name_elem = Mock()
        name_elem.text = "CertaPro Painters"
        
        # Setup rating extraction
        rating_elem = Mock()
        rating_elem.get_attribute.return_value = "4.9 stars 373 Reviews"
        
        # Setup phone extraction
        phone_elem = Mock()
        phone_elem.text = "(402) 493-5358"
        
        # Setup website extraction
        website_elem = Mock()
        website_elem.get_attribute.return_value = "https://www.certapro.com"
        
        # Setup URL extraction
        link_elem = Mock()
        link_elem.get_attribute.return_value = "https://maps.google.com/certapro"
        
        # Configure find_element to return appropriate mocks
        def find_element_side_effect(by, selector):
            if selector == ".qBF1Pd.fontHeadlineSmall":
                return name_elem
            elif selector == "span.ZkP5Je[aria-label]":
                return rating_elem
            elif selector == "span.UsdlK":
                return phone_elem
            elif selector == "a[data-value='Website']":
                return website_elem
            elif selector == "a.hfpxzc":
                return link_elem
            else:
                raise NoSuchElementException()
        
        element.find_element.side_effect = find_element_side_effect
        element.find_elements.return_value = []  # No photos
        
        # Extract details
        details = self.extractor.extract(element)
        
        # Verify extracted data
        self.assertEqual(details['name'], "CertaPro Painters")
        self.assertEqual(details['rating'], "4.9")
        self.assertEqual(details['reviews'], "373")
        self.assertEqual(details['phone'], "(402) 493-5358")
        self.assertEqual(details['website'], "https://www.certapro.com")
        self.assertTrue(details['has_website'])
        self.assertEqual(details['url'], "https://maps.google.com/certapro")
    
    def test_extract_standard_listing_without_website(self):
        """Test extraction from standard listing that has no website"""
        element = Mock()
        
        name_elem = Mock()
        name_elem.text = "Superb Painting, LLC"
        
        rating_elem = Mock()
        rating_elem.get_attribute.return_value = "5.0 stars 37 Reviews"
        
        def find_element_side_effect(by, selector):
            if selector == ".qBF1Pd.fontHeadlineSmall":
                return name_elem
            elif selector == "span.ZkP5Je[aria-label]":
                return rating_elem
            elif selector == "a[data-value='Website']":
                raise NoSuchElementException()  # No website
            else:
                raise NoSuchElementException()
        
        element.find_element.side_effect = find_element_side_effect
        element.find_elements.return_value = []
        
        details = self.extractor.extract(element)
        
        self.assertEqual(details['name'], "Superb Painting, LLC")
        self.assertEqual(details['rating'], "5.0")
        self.assertEqual(details['reviews'], "37")
        self.assertIsNone(details['website'])
        self.assertFalse(details['has_website'])


class TestCompactListingExtractor(unittest.TestCase):
    """Test extraction from compact listings (e.g., barber shops)"""
    
    def setUp(self):
        self.extractor = CompactListingExtractor()
    
    def test_can_handle_compact_listing_with_business_link_only(self):
        """Test that compact listing with business link but no website/action buttons is recognized"""
        element = Mock()
        
        def find_element_side_effect(by, selector):
            if selector == "a[data-value='Website']":
                raise NoSuchElementException()  # No visible website button
            elif selector == ".qty3Ue":
                raise NoSuchElementException()  # No qty3Ue container
            elif selector == ".Rwjeuc":
                raise NoSuchElementException()  # No action container
            elif selector == "a.hfpxzc":
                return Mock()  # Business link found
            else:
                raise NoSuchElementException()
        
        element.find_element.side_effect = find_element_side_effect
        
        self.assertTrue(self.extractor.can_handle(element))
    
    def test_can_handle_compact_listing_with_qty3Ue_container(self):
        """Test that compact listing with qty3Ue container is recognized"""
        element = Mock()
        
        def find_element_side_effect(by, selector):
            if selector == "a[data-value='Website']":
                raise NoSuchElementException()
            elif selector == ".qty3Ue":
                return Mock()  # Compact container found
            else:
                raise NoSuchElementException()
        
        element.find_element.side_effect = find_element_side_effect
        
        self.assertTrue(self.extractor.can_handle(element))
    
    def test_extract_compact_listing_without_driver(self):
        """Test extraction from compact listing when no driver provided"""
        element = Mock()
        
        name_elem = Mock()
        name_elem.text = "Ascension Barbershop"
        
        rating_elem = Mock()
        rating_elem.get_attribute.return_value = "4.9 stars 560 Reviews"
        
        def find_element_side_effect(by, selector):
            if selector == ".qBF1Pd.fontHeadlineSmall":
                return name_elem
            elif selector == "span.ZkP5Je[aria-label]":
                return rating_elem
            else:
                raise NoSuchElementException()
        
        element.find_element.side_effect = find_element_side_effect
        element.find_elements.return_value = []
        
        details = self.extractor.extract(element, driver=None)
        
        self.assertEqual(details['name'], "Ascension Barbershop")
        self.assertEqual(details['rating'], "4.9")
        self.assertEqual(details['reviews'], "560")
        self.assertIsNone(details['website'])
        self.assertFalse(details['has_website'])
        self.assertTrue(details.get('_needs_click_check', False))
    
    @patch('time.sleep')
    def test_extract_compact_listing_with_click_through(self, mock_sleep):
        """Test extraction from compact listing with click-through to find website"""
        element = Mock()
        driver = Mock()
        
        # Setup basic element data
        name_elem = Mock()
        name_elem.text = "Ascension Barbershop"
        
        rating_elem = Mock()
        rating_elem.get_attribute.return_value = "4.9 stars 560 Reviews"
        
        link_elem = Mock()
        link_elem.get_attribute.return_value = "https://maps.google.com/ascension"
        
        def find_element_side_effect(by, selector):
            if selector == ".qBF1Pd.fontHeadlineSmall":
                return name_elem
            elif selector == "span.ZkP5Je[aria-label]":
                return rating_elem
            elif selector == "a.hfpxzc":
                return link_elem
            else:
                raise NoSuchElementException()
        
        element.find_element.side_effect = find_element_side_effect
        element.find_elements.return_value = []
        
        # Setup driver for click-through
        driver.current_url = "https://maps.google.com/search"
        
        # Mock website element found after click
        website_link = Mock()
        website_link.get_attribute.return_value = "https://ascensionbarbershop.com"
        driver.find_element.return_value = website_link
        
        # Mock wait for navigation back
        wait_mock = Mock()
        driver.WebDriverWait = Mock(return_value=wait_mock)
        
        details = self.extractor.extract(element, driver=driver)
        
        # Verify click-through happened
        driver.execute_script.assert_called()  # Click happened
        driver.back.assert_called()  # Navigation back happened
        
        self.assertEqual(details['name'], "Ascension Barbershop")
        self.assertEqual(details['rating'], "4.9")
        self.assertEqual(details['reviews'], "560")
        self.assertEqual(details['website'], "https://ascensionbarbershop.com")
        self.assertTrue(details['has_website'])
    
    @patch('time.sleep')
    def test_extract_compact_listing_click_through_no_website(self, mock_sleep):
        """Test extraction when click-through finds no website"""
        element = Mock()
        driver = Mock()
        
        name_elem = Mock()
        name_elem.text = "Joe's Barber Shop"
        
        link_elem = Mock()
        
        def find_element_side_effect(by, selector):
            if selector == ".qBF1Pd.fontHeadlineSmall":
                return name_elem
            elif selector == "a.hfpxzc":
                return link_elem
            else:
                raise NoSuchElementException()
        
        element.find_element.side_effect = find_element_side_effect
        element.find_elements.return_value = []
        
        # No website found after click
        driver.find_element.side_effect = NoSuchElementException()
        
        details = self.extractor.extract(element, driver=driver)
        
        self.assertEqual(details['name'], "Joe's Barber Shop")
        self.assertIsNone(details['website'])
        self.assertFalse(details['has_website'])


class TestBusinessExtractorFactory(unittest.TestCase):
    """Test the factory that selects appropriate extractors"""
    
    def test_factory_selects_standard_extractor(self):
        """Test factory selects StandardListingExtractor for standard listings"""
        factory = BusinessExtractorFactory()
        element = Mock()
        
        # Mock element that looks like standard listing
        website_btn = Mock()
        element.find_element.return_value = website_btn
        
        with patch.object(StandardListingExtractor, 'extract') as mock_extract:
            mock_extract.return_value = {'name': 'Test', 'has_website': True}
            result = factory.extract(element)
            mock_extract.assert_called_once()
    
    def test_factory_selects_compact_extractor(self):
        """Test factory selects CompactListingExtractor for compact listings"""
        factory = BusinessExtractorFactory()
        element = Mock()
        
        # Mock element that looks like compact listing
        def find_element_side_effect(by, selector):
            if selector == "a[data-value='Website']":
                raise NoSuchElementException()
            elif selector == ".qty3Ue":
                return Mock()  # Has compact container
            else:
                raise NoSuchElementException()
        
        element.find_element.side_effect = find_element_side_effect
        
        with patch.object(CompactListingExtractor, 'extract') as mock_extract:
            mock_extract.return_value = {'name': 'Test', 'has_website': False}
            result = factory.extract(element)
            mock_extract.assert_called_once()
    
    def test_factory_fallback_to_standard(self):
        """Test factory falls back to StandardListingExtractor when no match"""
        factory = BusinessExtractorFactory()
        element = Mock()
        
        # Mock element that doesn't match any specific pattern
        element.find_element.side_effect = NoSuchElementException()
        
        with patch.object(StandardListingExtractor, 'extract') as mock_extract:
            mock_extract.return_value = {'name': 'Unknown', 'has_website': False}
            result = factory.extract(element)
            mock_extract.assert_called_once()


class TestIntegration(unittest.TestCase):
    """Integration tests for the main entry point"""
    
    def test_extract_business_details_with_click_through_enabled(self):
        """Test main entry point with click-through enabled"""
        element = Mock()
        driver = Mock()
        
        # Setup for compact listing
        def find_element_side_effect(by, selector):
            if selector == "a[data-value='Website']":
                raise NoSuchElementException()
            elif ".qty3Ue" in selector:
                return Mock()
            elif selector == ".qBF1Pd.fontHeadlineSmall":
                name_elem = Mock()
                name_elem.text = "Test Business"
                return name_elem
            else:
                raise NoSuchElementException()
        
        element.find_element.side_effect = find_element_side_effect
        element.find_elements.return_value = []
        
        result = extract_business_details(element, driver, enable_click_through=True)
        
        self.assertEqual(result['name'], "Test Business")
        # Driver was provided, so click-through should be attempted
        self.assertIsNotNone(result)
    
    def test_extract_business_details_with_click_through_disabled(self):
        """Test main entry point with click-through disabled"""
        element = Mock()
        driver = Mock()
        
        # Setup for compact listing
        def find_element_side_effect(by, selector):
            if selector == "a[data-value='Website']":
                raise NoSuchElementException()
            elif ".qty3Ue" in selector:
                return Mock()
            elif selector == ".qBF1Pd.fontHeadlineSmall":
                name_elem = Mock()
                name_elem.text = "Test Business"
                return name_elem
            else:
                raise NoSuchElementException()
        
        element.find_element.side_effect = find_element_side_effect
        element.find_elements.return_value = []
        
        result = extract_business_details(element, driver, enable_click_through=False)
        
        self.assertEqual(result['name'], "Test Business")
        # Click-through disabled, so website should not be found
        self.assertFalse(result.get('has_website', False))


class TestRealWorldScenarios(unittest.TestCase):
    """Tests based on real-world HTML examples"""
    
    def test_barber_shop_listing_recognition(self):
        """Test recognition of barber shop style compact listing"""
        element = Mock()
        
        # Barber shop listings have qty3Ue container but no visible Website button
        def find_element_side_effect(by, selector):
            if selector == "a[data-value='Website']":
                raise NoSuchElementException()  # No visible website button
            elif selector == ".qty3Ue":
                return Mock()  # Has compact container
            else:
                raise NoSuchElementException()
        
        element.find_element.side_effect = find_element_side_effect
        
        factory = BusinessExtractorFactory()
        # Should select CompactListingExtractor
        self.assertIsInstance(factory.extractors[1], CompactListingExtractor)
    
    def test_painter_listing_recognition(self):
        """Test recognition of painter style standard listing"""
        element = Mock()
        
        # Painter listings have visible Website and Directions buttons
        website_btn = Mock()
        website_btn.get_attribute.return_value = "https://certapro.com"
        
        def find_element_side_effect(by, selector):
            if selector == "a[data-value='Website']":
                return website_btn  # Has visible website button
            elif selector == ".Rwjeuc":
                return Mock()  # Has action button container
            else:
                raise NoSuchElementException()
        
        element.find_element.side_effect = find_element_side_effect
        
        factory = BusinessExtractorFactory()
        # Should select StandardListingExtractor
        self.assertIsInstance(factory.extractors[0], StandardListingExtractor)


if __name__ == '__main__':
    unittest.main()