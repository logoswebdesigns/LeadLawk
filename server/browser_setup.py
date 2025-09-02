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
        """Setup Chrome browser using official Selenium Docker guidance"""
        print("🚀 Setting up Chrome browser...")
        
        # Configure Chrome options
        options = Options()
        
        if self.headless:
            options.add_argument("--headless")
            print("👻 Running in headless mode")
        else:
            print("👀 Running in visible mode")
        
        # Standard Chrome options for containerized environment
        options.add_argument('--ignore-ssl-errors=yes')
        options.add_argument('--ignore-certificate-errors')
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-dev-shm-usage")
        options.add_argument("--disable-gpu")
        options.add_argument("--window-size=1920,1080")
        
        # Safe performance optimizations that won't break Google Maps
        options.add_argument("--disable-blink-features=AutomationControlled")
        options.add_argument("--disable-extensions")
        options.add_argument("--disable-default-apps")
        options.add_argument("--disable-features=TranslateUI")
        
        # Memory optimizations - keep conservative to ensure stability
        options.add_argument("--memory-pressure-off")
        options.add_argument("--max_old_space_size=4096")
        
        # Hub URL for Selenium standalone-chrome container
        hub_url = os.environ.get('SELENIUM_HUB_URL', 'http://selenium-chrome:4444/wd/hub')
        print(f"🐳 Connecting to Selenium Hub at: {hub_url}")
        
        try:
            # Use official webdriver.Remote approach
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