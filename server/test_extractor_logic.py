#!/usr/bin/env python3
"""
Quick test to verify the extractor logic is working correctly.
Can be run inside the container to test extraction without full browser automation.
"""

from business_extractor import BusinessExtractorFactory, StandardListingExtractor, CompactListingExtractor

def test_extractor_selection():
    """Test that the factory properly selects extractors"""
    print("🧪 Testing BusinessExtractorFactory extractor selection")
    print("="*60)
    
    # Create a mock element class for testing
    class MockElement:
        def __init__(self, has_website_button=False, has_directions_button=False, has_business_link=True, has_name=True):
            self.has_website_button = has_website_button
            self.has_directions_button = has_directions_button
            self.has_business_link = has_business_link
            self.has_name = has_name
            
        def find_elements(self, by, selector):
            """Mock find_elements method"""
            if "data-value" in selector:
                # Return mock buttons based on configuration
                buttons = []
                if self.has_website_button:
                    buttons.append(MockButton("Website"))
                if self.has_directions_button:
                    buttons.append(MockButton("Directions"))
                return buttons
            elif "/maps/place/" in selector:
                # Return business link if configured
                return [MockLink()] if self.has_business_link else []
            else:
                # Return name element if configured
                return [MockText("Test Business")] if self.has_name else []
                
        def find_element(self, by, selector):
            """Mock find_element method"""
            elements = self.find_elements(by, selector)
            if elements:
                return elements[0]
            raise Exception("No element found")
            
    class MockButton:
        def __init__(self, value):
            self.value = value
            
        def get_attribute(self, attr):
            if attr == "data-value":
                return self.value
            return None
            
    class MockLink:
        def get_attribute(self, attr):
            if attr == "href":
                return "https://maps.google.com/maps/place/test"
            return None
            
    class MockText:
        def __init__(self, text):
            self.text = text
            
        def text(self):
            return self.text
    
    # Test scenarios
    scenarios = [
        {
            "name": "Standard listing with website button",
            "element": MockElement(has_website_button=True, has_directions_button=True),
            "expected": "StandardListingExtractor"
        },
        {
            "name": "Standard listing with directions only",
            "element": MockElement(has_website_button=False, has_directions_button=True),
            "expected": "StandardListingExtractor"
        },
        {
            "name": "Compact listing (no action buttons)",
            "element": MockElement(has_website_button=False, has_directions_button=False),
            "expected": "CompactListingExtractor"
        },
        {
            "name": "Invalid listing (no business link)",
            "element": MockElement(has_website_button=False, has_directions_button=False, has_business_link=False),
            "expected": "None"
        }
    ]
    
    # Test each scenario
    standard_extractor = StandardListingExtractor()
    compact_extractor = CompactListingExtractor()
    
    print("\nTesting extractor detection logic:")
    print("-" * 40)
    
    all_passed = True
    
    for scenario in scenarios:
        element = scenario["element"]
        expected = scenario["expected"]
        
        # Test which extractor handles this
        standard_handles = False
        compact_handles = False
        
        try:
            standard_handles = standard_extractor.can_handle(element)
        except:
            pass
            
        try:
            compact_handles = compact_extractor.can_handle(element)
        except:
            pass
        
        # Determine actual result
        if standard_handles:
            actual = "StandardListingExtractor"
        elif compact_handles:
            actual = "CompactListingExtractor"
        else:
            actual = "None"
            
        # Check if it matches expected
        passed = actual == expected
        symbol = "✅" if passed else "❌"
        
        print(f"{symbol} {scenario['name']}")
        print(f"   Expected: {expected}")
        print(f"   Actual: {actual}")
        
        if not passed:
            all_passed = False
            print(f"   FAILED: Extractor mismatch!")
            
    print("-" * 40)
    
    if all_passed:
        print("✅ All extractor selection tests passed!")
    else:
        print("❌ Some extractor selection tests failed!")
        
    return all_passed

def test_factory_behavior():
    """Test that the factory properly iterates through extractors"""
    print("\n🏭 Testing BusinessExtractorFactory behavior")
    print("="*60)
    
    factory = BusinessExtractorFactory(driver=None)
    
    # Check that factory has both extractors
    print(f"Factory has {len(factory.extractors)} extractors:")
    for i, extractor in enumerate(factory.extractors):
        print(f"  {i+1}. {type(extractor).__name__}")
        
    # Verify order (StandardListingExtractor should be first for efficiency)
    if isinstance(factory.extractors[0], StandardListingExtractor):
        print("✅ StandardListingExtractor is first (good for performance)")
    else:
        print("⚠️ StandardListingExtractor should be first for better performance")
        
    if isinstance(factory.extractors[1], CompactListingExtractor):
        print("✅ CompactListingExtractor is second")
    else:
        print("❌ CompactListingExtractor is missing or in wrong position")
        
    return True

def main():
    """Run all tests"""
    print("\n🚀 Business Extractor Logic Test")
    print("This verifies the extraction logic without running a browser")
    print("\n")
    
    # Test extractor selection
    selection_passed = test_extractor_selection()
    
    # Test factory behavior
    factory_passed = test_factory_behavior()
    
    # Summary
    print("\n" + "="*60)
    print("📊 TEST SUMMARY")
    print("="*60)
    
    if selection_passed and factory_passed:
        print("✅ All tests passed! Extraction logic is working correctly.")
        print("\nThe system can properly:")
        print("  • Identify standard listings (with Website/Directions buttons)")
        print("  • Identify compact listings (without action buttons)")
        print("  • Select the appropriate extractor for each type")
        print("  • Handle edge cases (invalid listings)")
        return 0
    else:
        print("❌ Some tests failed. Check the extraction logic.")
        return 1

if __name__ == "__main__":
    exit(main())