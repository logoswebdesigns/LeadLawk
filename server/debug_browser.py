#!/usr/bin/env python3
"""
Debug browser setup issues
"""

import os
from selenium import webdriver
from selenium.webdriver.chrome.options import Options

def test_browser_setup():
    """Test browser setup directly"""
    print("🧪 Testing browser setup...")
    
    chrome_options = Options()
    selenium_hub_url = os.environ.get('SELENIUM_HUB_URL', 'http://selenium-chrome:4444/wd/hub')
    print(f"🔗 Connecting to: {selenium_hub_url}")
    
    # Options for containerized Chrome
    chrome_options.add_argument("--no-sandbox")
    chrome_options.add_argument("--disable-dev-shm-usage")
    chrome_options.add_argument("--disable-gpu")
    chrome_options.add_argument("--window-size=1920,1080")
    
    try:
        print("📞 Creating Remote WebDriver...")
        driver = webdriver.Remote(
            command_executor=selenium_hub_url,
            options=chrome_options
        )
        print("✅ Success! Browser connected")
        driver.quit()
        print("✅ Browser closed successfully")
        return True
    except Exception as e:
        print(f"❌ Error: {e}")
        print(f"❌ Error type: {type(e).__name__}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    test_browser_setup()