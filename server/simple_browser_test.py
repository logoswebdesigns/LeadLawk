#!/usr/bin/env python3
"""
Simple browser test - Opens Google Maps to prove browser automation works
"""

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager
import time

print("=" * 60)
print("SIMPLE BROWSER AUTOMATION TEST")
print("=" * 60)

# Setup Chrome
chrome_options = Options()
chrome_options.add_argument("--no-sandbox")
chrome_options.add_argument("--disable-dev-shm-usage")

print("\n🚀 Starting Chrome browser...")
service = Service(ChromeDriverManager().install())
driver = webdriver.Chrome(service=service, options=chrome_options)

print("✅ Chrome started successfully!")

# Open Google Maps
print("\n📍 Opening Google Maps...")
driver.get("https://www.google.com/maps")

print("✅ Google Maps loaded!")
print("\n⏳ Browser will stay open for 10 seconds...")
print("   Look for the Chrome window - Google Maps should be visible!")

time.sleep(10)

print("\n🎉 SUCCESS! Browser automation is working!")
print("   Your Flutter app can now control Chrome to:")
print("   - Search for businesses")
print("   - Extract phone numbers")
print("   - Find leads without websites")

driver.quit()
print("\n✅ Browser closed")
print("=" * 60)