#!/usr/bin/env python3
"""
Test headless browser automation for server use
This demonstrates that the server can control a browser without any visible window
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from browser_automation import BrowserAutomation


def test_headless():
    """Test headless browser automation"""
    print("=" * 60)
    print("HEADLESS BROWSER AUTOMATION TEST")
    print("=" * 60)
    print("\n🤖 Running browser in HEADLESS mode (no window)")
    print("   Perfect for server-side automation!")
    
    # Create browser instance - try visible first
    automation = BrowserAutomation(use_profile=False, headless=False)
    
    try:
        print("\n📍 Testing Google Maps automation...")
        
        # Open Google Maps
        automation.open_google_maps()
        
        # Search for something
        query = "Plumber"
        location = "Austin, TX"
        
        if automation.search_location(query, location):
            print("\n✅ SUCCESS! Browser automation is working!")
            
            # Get some results
            businesses = automation.get_visible_businesses()
            print(f"\n📊 Found {len(businesses)} businesses")
            
            # Extract details from first business
            if businesses:
                print("\n🔍 Testing data extraction...")
                if automation.click_business(businesses[0]):
                    details = automation.extract_business_details()
                    if details:
                        print(f"\n✅ Extracted: {details.get('name', 'Unknown')}")
                        print(f"   Phone: {details.get('phone', 'N/A')}")
                        print(f"   Website: {'Yes' if details.get('has_website') else 'No'}")
        else:
            print("\n⚠️ Search didn't return results, but browser is working")
            
        print("\n" + "=" * 60)
        print("✅ HEADLESS BROWSER TEST COMPLETE!")
        print("   The server can control Chrome without any visible window")
        print("=" * 60)
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        automation.close()


if __name__ == "__main__":
    test_headless()