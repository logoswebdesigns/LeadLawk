#!/usr/bin/env python3
"""Simple test script to trigger a PageSpeed deletion with low threshold"""

import requests
import time
import json

BASE_URL = "http://localhost:8000"

def test_pagespeed_deletion():
    """Test PageSpeed deletion with a business that has a website"""
    
    print("🧪 Testing PageSpeed deletion animation...")
    
    # Step 1: Create a simple search job with PageSpeed enabled and high threshold
    job_data = {
        "industry": "web design",
        "location": "Omaha, NE",
        "limit": 3,
        "filters": {
            "requires_no_website": False,  # We WANT businesses with websites
            "min_rating": 0,
            "min_reviews": 0
        },
        "enable_pagespeed": True,
        "pagespeed_threshold": 95  # Very high threshold - most sites will fail
    }
    
    print(f"📍 Creating job with PageSpeed threshold of {job_data['pagespeed_threshold']}...")
    response = requests.post(f"{BASE_URL}/api/automation/start", json=job_data)
    
    if response.status_code != 200:
        print(f"❌ Failed to start job: {response.text}")
        return
    
    job_id = response.json()["job_id"]
    print(f"✅ Job created: {job_id}")
    
    # Step 2: Monitor job progress
    print("⏳ Waiting for job to complete and PageSpeed tests to run...")
    max_wait = 180  # 3 minutes max
    start_time = time.time()
    
    while time.time() - start_time < max_wait:
        # Check job status
        status_response = requests.get(f"{BASE_URL}/api/automation/status/{job_id}")
        if status_response.status_code == 200:
            status = status_response.json()
            print(f"   Status: {status.get('status')}, Progress: {status.get('progress', 0)}%, Leads: {status.get('leads_found', 0)}")
            
            if status.get('status') == 'completed':
                print("✅ Job completed!")
                break
        
        time.sleep(5)
    
    # Step 3: Check for leads and their PageSpeed scores
    print("\n📊 Checking leads and PageSpeed scores...")
    leads_response = requests.get(f"{BASE_URL}/api/leads")
    
    if leads_response.status_code == 200:
        leads = leads_response.json()
        recent_leads = [l for l in leads if l.get('source_job_id') == job_id]
        
        print(f"Found {len(recent_leads)} leads from this job:")
        for lead in recent_leads:
            mobile = lead.get('mobile_pagespeed_score', 'N/A')
            desktop = lead.get('desktop_pagespeed_score', 'N/A')
            print(f"  - {lead['business_name']}: Mobile={mobile}, Desktop={desktop}")
        
        # Check if any were deleted
        print("\n🔍 Checking for deletions due to low PageSpeed scores...")
        print("⚠️  Watch the Flutter app - leads with scores below 95 should show")
        print("   a red pulsing animation for 2 seconds before being removed!")
    
    print("\n✨ Test complete! Check the Flutter app for the deletion animation.")

if __name__ == "__main__":
    test_pagespeed_deletion()
