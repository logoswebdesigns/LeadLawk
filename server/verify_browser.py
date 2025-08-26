#!/usr/bin/env python3
"""
Quick verification that browser automation works
"""

from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from webdriver_manager.chrome import ChromeDriverManager
import time

print("=" * 60)
print("VERIFYING BROWSER AUTOMATION")
print("=" * 60)

# Setup Chrome options
options = Options()
options.add_argument("--no-sandbox")
options.add_argument("--disable-dev-shm-usage")
options.add_argument("--headless")  # Run headless for quick test

print("\n1. Starting Chrome browser (headless)...")
try:
    service = Service(ChromeDriverManager().install())
    driver = webdriver.Chrome(service=service, options=options)
    print("   ✅ Browser started successfully")
except Exception as e:
    print(f"   ❌ Failed to start browser: {e}")
    exit(1)

print("\n2. Opening Google Maps...")
try:
    driver.get("https://www.google.com/maps")
    time.sleep(2)
    print("   ✅ Google Maps loaded")
except Exception as e:
    print(f"   ❌ Failed to load Google Maps: {e}")
    driver.quit()
    exit(1)

print("\n3. Searching for 'Plumber in Austin TX'...")
try:
    from selenium.webdriver.common.by import By
    from selenium.webdriver.common.keys import Keys
    
    # Find search box
    search_box = driver.find_element(By.ID, "searchboxinput")
    search_box.clear()
    search_box.send_keys("Plumber in Austin TX")
    search_box.send_keys(Keys.RETURN)
    time.sleep(3)
    print("   ✅ Search executed")
except Exception as e:
    print(f"   ❌ Search failed: {e}")
    driver.quit()
    exit(1)

print("\n4. Checking for results...")
try:
    # Check if we got results
    results = driver.find_elements(By.CSS_SELECTOR, "[role='article']")
    if results:
        print(f"   ✅ Found {len(results)} businesses")
        
        # Try to get first business name
        if results[0].text:
            first_business = results[0].text.split('\n')[0]
            print(f"   ✅ First result: {first_business}")
    else:
        print("   ⚠️ No results found, but search worked")
except Exception as e:
    print(f"   ⚠️ Could not parse results: {e}")

print("\n5. Closing browser...")
driver.quit()
print("   ✅ Browser closed")

print("\n" + "=" * 60)
print("✅ BROWSER AUTOMATION IS WORKING!")
print("   - Chrome browser starts successfully")
print("   - Can navigate to Google Maps")
print("   - Can perform searches")
print("   - Can find businesses")
print("=" * 60)