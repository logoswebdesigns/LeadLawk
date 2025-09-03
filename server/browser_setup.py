#!/usr/bin/env python3
"""
Browser setup and configuration utilities - Following official Selenium Docker guidance
"""

import os
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.support.ui import WebDriverWait


class BrowserSetup:
    def __init__(self, use_profile=False, headless=False):
        self.use_profile = use_profile
        self.headless = headless
        self.driver = None

    def setup_browser(self):
        """Setup Chrome browser - let ChromeDriver manage temp profiles"""
        print("🚀 Setting up Chrome browser...")
        
        # Configure Chrome options - minimal for stability
        options = Options()
        
        # Safe flags for Chrome in Docker (required)
        if self.headless:
            options.add_argument("--headless=new")  # Use new headless mode
            print("👻 Running in headless mode")
        else:
            print("👀 Running in visible mode")
            
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-dev-shm-usage")
        
        # Optional: reduce crashes/noise
        options.add_argument("--remote-allow-origins=*")
        options.add_argument("--window-size=1920,1080")
        
        # Hub URL for Selenium 4 (no /wd/hub needed)
        hub_url = os.environ.get('SELENIUM_HUB_URL', 'http://selenium-chrome:4444')
        print(f"🐳 Connecting to Selenium Hub at: {hub_url}")
        
        try:
            # Create Remote driver - ChromeDriver manages temp profiles
            self.driver = webdriver.Remote(
                command_executor=hub_url,
                options=options
            )
            self.wait = WebDriverWait(self.driver, 10)
            print("✅ Remote browser initialized successfully!")
            return self.driver
        except Exception as e:
            print(f"❌ Failed to initialize Remote Chrome: {e}")
            raise

    def close(self):
        """Close the browser"""
        if self.driver:
            try:
                self.driver.quit()
                print("✅ Browser closed successfully")
            except Exception as e:
                print(f"❌ Error closing browser: {str(e)}")