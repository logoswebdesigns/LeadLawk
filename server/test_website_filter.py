#!/usr/bin/env python3
"""
Test that website filter properly handles all three states:
- None: Both businesses with and without websites
- True: Only businesses with websites
- False: Only businesses without websites
"""

import requests
import json
import time
import sqlite3
import sys

def test_website_filter():
    """Test all three website filter states"""
    
    base_url = "http://localhost:8000"
    db_path = "/Users/jacobanderson/Documents/GitHub/LeadLawk/server/db/leadloq.db"
    
    # Common test parameters
    base_payload = {
        "industries": ["plumber"],
        "locations": ["Omaha, NE"],
        "limit": 5,
        "min_rating": 4.0,
        "min_reviews": 5,
        "recent_review_months": 24,
        "enable_pagespeed": True
    }
    
    print("🧪 Testing Website Filter States...")
    print("=" * 50)
    
    # Test 1: requires_website = None (both)
    print("\n📤 Test 1: requires_website = None (get BOTH)")
    payload = {**base_payload, "requires_website": None}
    
    response = requests.post(f"{base_url}/jobs/parallel", json=payload)
    if response.status_code != 200:
        print(f"❌ Test 1 failed: {response.text}")
        return False
    
    job1 = response.json()
    print(f"✅ Job created: {job1['parent_job_id']}")
    
    # Wait for job to complete
    time.sleep(15)
    
    # Check results
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("""
        SELECT business_name, has_website, website_url IS NOT NULL as has_url
        FROM leads 
        WHERE created_at > datetime('now', '-1 minute')
        ORDER BY created_at DESC
        LIMIT 10
    """)
    results = cursor.fetchall()
    
    has_with_website = any(r[1] for r in results)
    has_without_website = any(not r[1] for r in results)
    
    print(f"Results: {len(results)} leads found")
    for name, has_website, has_url in results:
        print(f"  - {name}: has_website={has_website}, has_url={has_url}")
    
    if len(results) > 0:
        print(f"✅ Test 1 passed: Found {len(results)} leads")
        print(f"  Has businesses with websites: {has_with_website}")
        print(f"  Has businesses without websites: {has_without_website}")
    else:
        print("⚠️ Test 1: No leads found")
    
    # Test 2: requires_website = True (only with websites)
    print("\n📤 Test 2: requires_website = True (ONLY with websites)")
    payload = {**base_payload, "requires_website": True}
    
    response = requests.post(f"{base_url}/jobs/parallel", json=payload)
    if response.status_code != 200:
        print(f"❌ Test 2 failed: {response.text}")
        return False
    
    job2 = response.json()
    print(f"✅ Job created: {job2['parent_job_id']}")
    
    time.sleep(15)
    
    cursor.execute("""
        SELECT business_name, has_website, website_url
        FROM leads 
        WHERE created_at > datetime('now', '-30 seconds')
        AND created_at > datetime('now', '-1 minute', '+30 seconds')
        ORDER BY created_at DESC
        LIMIT 10
    """)
    results = cursor.fetchall()
    
    all_have_websites = all(r[1] and r[2] for r in results)
    
    print(f"Results: {len(results)} leads found")
    for name, has_website, website_url in results:
        print(f"  - {name}: has_website={has_website}, url={website_url[:30] if website_url else 'None'}...")
    
    if all_have_websites and len(results) > 0:
        print(f"✅ Test 2 passed: All {len(results)} leads have websites")
    else:
        print(f"❌ Test 2 failed: Found leads without websites when requires_website=True")
    
    # Test 3: requires_website = False (only without websites)
    print("\n📤 Test 3: requires_website = False (ONLY without websites)")
    payload = {**base_payload, "requires_website": False}
    
    response = requests.post(f"{base_url}/jobs/parallel", json=payload)
    if response.status_code != 200:
        print(f"❌ Test 3 failed: {response.text}")
        return False
    
    job3 = response.json()
    print(f"✅ Job created: {job3['parent_job_id']}")
    
    time.sleep(15)
    
    cursor.execute("""
        SELECT business_name, has_website, website_url
        FROM leads 
        WHERE created_at > datetime('now', '-30 seconds')
        ORDER BY created_at DESC
        LIMIT 10
    """)
    results = cursor.fetchall()
    
    none_have_websites = all(not r[1] and not r[2] for r in results)
    
    print(f"Results: {len(results)} leads found")
    for name, has_website, website_url in results:
        print(f"  - {name}: has_website={has_website}, url={website_url if website_url else 'None'}")
    
    if none_have_websites and len(results) > 0:
        print(f"✅ Test 3 passed: All {len(results)} leads have NO websites")
    else:
        print(f"❌ Test 3 failed: Found leads with websites when requires_website=False")
    
    conn.close()
    
    print("\n" + "=" * 50)
    print("🎉 Website filter tests complete!")
    
    return True

if __name__ == "__main__":
    success = test_website_filter()
    sys.exit(0 if success else 1)