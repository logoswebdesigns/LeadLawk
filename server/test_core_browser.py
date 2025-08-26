#!/usr/bin/env python3
"""
Core browser automation test - verify essential functionality
"""

from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from webdriver_manager.chrome import ChromeDriverManager
import time

print("\n" + "=" * 60)
print("CORE BROWSER AUTOMATION TEST")
print("=" * 60)

# Test 1: Can we start Chrome?
print("\n✓ TEST 1: Starting Chrome...")
options = Options()
options.add_argument("--headless")  # Headless for speed
options.add_argument("--no-sandbox")
options.add_argument("--disable-dev-shm-usage")

try:
    service = Service(ChromeDriverManager().install())
    driver = webdriver.Chrome(service=service, options=options)
    print("  ✅ PASS: Chrome started successfully")
except Exception as e:
    print(f"  ❌ FAIL: {e}")
    exit(1)

# Test 2: Can we navigate to a website?
print("\n✓ TEST 2: Navigating to Google...")
try:
    driver.get("https://www.google.com")
    time.sleep(1)
    assert "Google" in driver.title
    print("  ✅ PASS: Navigation works")
except Exception as e:
    print(f"  ❌ FAIL: {e}")
    driver.quit()
    exit(1)

# Test 3: Can we interact with elements?
print("\n✓ TEST 3: Finding and interacting with elements...")
try:
    from selenium.webdriver.common.by import By
    search_box = driver.find_element(By.NAME, "q")
    search_box.send_keys("Selenium test")
    print("  ✅ PASS: Can interact with page elements")
except Exception as e:
    print(f"  ❌ FAIL: {e}")
    driver.quit()
    exit(1)

# Test 4: Can we get page content?
print("\n✓ TEST 4: Reading page content...")
try:
    page_source = driver.page_source
    assert len(page_source) > 1000
    print(f"  ✅ PASS: Can read page content ({len(page_source)} characters)")
except Exception as e:
    print(f"  ❌ FAIL: {e}")
    driver.quit()
    exit(1)

# Clean up
driver.quit()

print("\n" + "=" * 60)
print("✅ ALL CORE TESTS PASSED!")
print("\nBrowser automation is fully functional:")
print("  • Chrome browser starts correctly")
print("  • Can navigate to websites")
print("  • Can interact with page elements")
print("  • Can extract page content")
print("\nThe system is ready to automate Google Maps")
print("and find leads for your business!")
print("=" * 60)