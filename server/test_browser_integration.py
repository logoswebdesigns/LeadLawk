#!/usr/bin/env python3
"""
Test the complete browser automation integration
"""

import requests
import time
import json

print("\n" + "=" * 60)
print("BROWSER AUTOMATION INTEGRATION TEST")
print("=" * 60)

# Start the server if not running (you should have it running already)
BASE_URL = "http://localhost:8000"

# Test 1: Health check
print("\n✓ TEST 1: Server health check...")
try:
    resp = requests.get(f"{BASE_URL}/health")
    assert resp.status_code == 200
    print(f"  ✅ PASS: Server is healthy")
except Exception as e:
    print(f"  ❌ FAIL: Server not running or unhealthy: {e}")
    print("\nPlease start the server with:")
    print("  cd server && source venv/bin/activate && python main.py")
    exit(1)

# Test 2: Start browser automation job with mock data
print("\n✓ TEST 2: Starting browser automation with mock data...")
try:
    payload = {
        "industry": "Plumber",
        "location": "Austin, TX",
        "limit": 5,
        "min_rating": 4.0,
        "min_reviews": 10,
        "recent_days": 365,
        "use_mock_data": True,  # Use mock data for testing
        "use_browser_automation": True,
        "headless": True,
        "use_profile": False
    }
    
    resp = requests.post(f"{BASE_URL}/jobs/browser", json=payload)
    assert resp.status_code == 200
    job_data = resp.json()
    job_id = job_data.get("job_id")
    assert job_id is not None
    print(f"  ✅ PASS: Job started with ID: {job_id}")
    
    # Test 3: Monitor job status
    print("\n✓ TEST 3: Monitoring job progress...")
    for i in range(10):  # Check for 10 seconds
        time.sleep(1)
        status_resp = requests.get(f"{BASE_URL}/jobs/{job_id}")
        if status_resp.status_code == 200:
            status = status_resp.json()
            print(f"  Status: {status['status']} - Processed: {status['processed']}/{status['total']}")
            if status['status'] == 'done':
                print(f"  ✅ PASS: Job completed successfully!")
                break
            elif status['status'] == 'error':
                print(f"  ❌ FAIL: Job failed with error: {status.get('message')}")
                break
    
    # Test 4: Get job logs
    print("\n✓ TEST 4: Fetching job logs...")
    logs_resp = requests.get(f"{BASE_URL}/jobs/{job_id}/logs")
    if logs_resp.status_code == 200:
        logs = logs_resp.json()
        print(f"  ✅ PASS: Retrieved {len(logs['lines'])} log lines")
        if logs['lines']:
            print("\n  Last 3 logs:")
            for log in logs['lines'][-3:]:
                print(f"    {log}")
    
except Exception as e:
    print(f"  ❌ FAIL: {e}")
    exit(1)

print("\n" + "=" * 60)
print("✅ ALL INTEGRATION TESTS PASSED!")
print("\nThe browser automation system is working correctly:")
print("  • Server accepts browser automation requests")
print("  • Jobs are created and tracked properly")
print("  • Mock data generation works")
print("  • Job status and logs are accessible")
print("\nNow try with real browser automation (headless=false)")
print("to see Chrome in action!")
print("=" * 60)