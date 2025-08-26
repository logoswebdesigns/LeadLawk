#!/usr/bin/env python3
"""
Debug script to test Google Maps selectors in the containerized environment
"""

import time
import os
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.options import Options

def debug_selectors():
    print("🚀 Starting debug session...")
    
    chrome_options = Options()
    selenium_hub_url = os.environ.get('SELENIUM_HUB_URL', 'http://selenium-chrome:4444/wd/hub')
    
    # Use visible mode for debugging
    chrome_options.add_argument("--window-size=1920,1080")
    chrome_options.add_argument("--no-sandbox")
    chrome_options.add_argument("--disable-dev-shm-usage")
    chrome_options.add_argument("--disable-gpu")
    
    try:
        driver = webdriver.Remote(
            command_executor=selenium_hub_url,
            options=chrome_options
        )
        wait = WebDriverWait(driver, 10)
        
        print("✅ Connected to Selenium Hub")
        
        # Navigate to Google Maps and search
        driver.get("https://www.google.com/maps")
        time.sleep(2)
        
        search_box = wait.until(EC.presence_of_element_located((By.ID, "searchboxinput")))
        search_box.clear()
        search_box.send_keys("Nelson Contracting LLC Omaha, NE")
        search_box.send_keys(Keys.RETURN)
        
        time.sleep(5)  # Wait for results and details to load
        
        print("🔍 Searching for rating and review elements...")
        
        # Try to find rating elements
        rating_selectors = [
            "span[role='img'][aria-label*='stars']",
            "span[role='img'][aria-label*='star']", 
            "div[class*='rating']",
            "span[class*='rating']",
            "[aria-label*='stars']",
            "[aria-label*='star']",
            "div[data-value]",
        ]
        
        for selector in rating_selectors:
            try:
                elements = driver.find_elements(By.CSS_SELECTOR, selector)
                if elements:
                    print(f"✅ Found {len(elements)} elements for: {selector}")
                    for i, elem in enumerate(elements[:3]):  # Show first 3
                        aria_label = elem.get_attribute("aria-label")
                        text = elem.text
                        classes = elem.get_attribute("class")
                        print(f"   [{i}] aria-label: {aria_label}")
                        print(f"   [{i}] text: {text}")
                        print(f"   [{i}] class: {classes}")
                else:
                    print(f"❌ No elements found for: {selector}")
            except Exception as e:
                print(f"❌ Error with selector {selector}: {e}")
        
        print("\n🔍 Searching for review count elements...")
        
        # Try to find review elements  
        review_selectors = [
            "span[aria-label*='review']",
            "button[aria-label*='review']",
            "span[aria-label*='Review']", 
            "[aria-label*='review']",
            "[aria-label*='Review']",
            "button[data-value]",
            "span:contains('review')",
            "button:contains('review')",
        ]
        
        for selector in review_selectors:
            try:
                if 'contains' in selector:
                    # Skip XPath-style selectors for now
                    continue
                    
                elements = driver.find_elements(By.CSS_SELECTOR, selector)
                if elements:
                    print(f"✅ Found {len(elements)} elements for: {selector}")
                    for i, elem in enumerate(elements[:3]):  # Show first 3
                        aria_label = elem.get_attribute("aria-label")
                        text = elem.text
                        classes = elem.get_attribute("class")
                        print(f"   [{i}] aria-label: {aria_label}")
                        print(f"   [{i}] text: {text}")
                        print(f"   [{i}] class: {classes}")
                else:
                    print(f"❌ No elements found for: {selector}")
            except Exception as e:
                print(f"❌ Error with selector {selector}: {e}")
                
        print("\n🔍 Looking for all buttons and spans with aria-labels...")
        
        # Get all elements that might contain rating/review info
        all_elements = driver.find_elements(By.CSS_SELECTOR, "*[aria-label]")
        rating_review_elements = []
        
        for elem in all_elements:
            aria_label = elem.get_attribute("aria-label") or ""
            if any(word in aria_label.lower() for word in ['star', 'rating', 'review']):
                rating_review_elements.append(elem)
        
        print(f"Found {len(rating_review_elements)} elements with rating/review related aria-labels:")
        
        for i, elem in enumerate(rating_review_elements[:10]):  # Show first 10
            aria_label = elem.get_attribute("aria-label")
            tag_name = elem.tag_name
            classes = elem.get_attribute("class")
            text = elem.text[:50] if elem.text else ""
            print(f"   [{i}] {tag_name}: {aria_label}")
            print(f"       class: {classes}")
            print(f"       text: {text}")
            
        time.sleep(30)  # Keep browser open for manual inspection
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        if 'driver' in locals():
            driver.quit()

if __name__ == "__main__":
    debug_selectors()