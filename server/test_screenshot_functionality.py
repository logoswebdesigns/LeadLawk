#!/usr/bin/env python3
"""
Test script to verify screenshot capture functionality and logging
"""
import requests
import time
import json
import os

def test_screenshot_capture():
    """Test that screenshots are captured for qualified leads"""
    print("🧪 Testing screenshot capture functionality...")
    
    base_url = "http://localhost:8000"
    
    # Step 1: Start a browser job
    print("\n📋 Step 1: Starting browser automation job...")
    response = requests.post(f"{base_url}/jobs/browser", json={
        "industry": "contractor",
        "location": "Papillion", 
        "limit": 2,
        "min_rating": 4.0
    })
    
    if response.status_code != 200:
        print(f"❌ Failed to start job: {response.status_code} - {response.text}")
        return False
    
    job_data = response.json()
    job_id = job_data["job_id"]
    print(f"✅ Job started with ID: {job_id}")
    
    # Step 2: Wait for job completion and collect logs
    print("\n📋 Step 2: Monitoring job progress...")
    screenshot_logs = []
    business_screenshots = []
    qualified_leads = []
    
    max_wait = 60  # 1 minute timeout
    start_time = time.time()
    job_completed = False
    
    while time.time() - start_time < max_wait and not job_completed:
        # Get job status
        status_response = requests.get(f"{base_url}/jobs/{job_id}")
        if status_response.status_code == 200:
            status = status_response.json()
            print(f"🔄 Job status: {status.get('status', 'unknown')}")
            
            if status.get("status") in ["completed", "error"]:
                job_completed = True
                break
        
        # Get logs
        logs_response = requests.get(f"{base_url}/logs?tail=50")
        if logs_response.status_code == 200:
            logs = logs_response.json()
            for log in logs.get("lines", []):
                # Look for screenshot-related logs
                if "📸 About to take business screenshot" in log:
                    screenshot_logs.append(log)
                elif "business_" in log and ".png" in log:
                    business_screenshots.append(log)
                elif "✅ Added:" in log:
                    qualified_leads.append(log)
        
        time.sleep(2)
    
    # Step 3: Analyze results
    print("\n📋 Step 3: Analyzing results...")
    
    # Check for screenshot logs
    print(f"\n📸 Screenshot initiation logs found: {len(screenshot_logs)}")
    for log in screenshot_logs:
        print(f"  - {log}")
    
    # Check for business screenshot files
    print(f"\n🖼️ Business screenshot files created: {len(business_screenshots)}")
    for log in business_screenshots:
        print(f"  - {log}")
    
    # Check for qualified leads
    print(f"\n👥 Qualified leads found: {len(qualified_leads)}")
    for log in qualified_leads:
        print(f"  - {log}")
    
    # Step 4: Verify screenshot files exist
    print("\n📋 Step 4: Verifying screenshot files exist...")
    screenshot_dir = "/Users/jacobanderson/Documents/GitHub/LeadLawk/server/screenshots"
    if os.path.exists(screenshot_dir):
        business_files = [f for f in os.listdir(screenshot_dir) 
                         if f.endswith('.png') and 'business_' in f]
        print(f"📁 Business screenshot files on disk: {len(business_files)}")
        for file in business_files[-5:]:  # Show last 5 files
            print(f"  - {file}")
    else:
        print("❌ Screenshot directory not found")
        return False
    
    # Step 5: Results summary
    print("\n📋 Step 5: Test Results Summary...")
    
    success_criteria = {
        "Job completed successfully": job_completed,
        "Screenshot initiation logs present": len(screenshot_logs) > 0,
        "Business screenshot files created": len(business_files) > 0,
        "Qualified leads processed": len(qualified_leads) > 0
    }
    
    all_passed = True
    for criteria, passed in success_criteria.items():
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"  {status} {criteria}")
        if not passed:
            all_passed = False
    
    print(f"\n🎯 Overall Test Result: {'✅ PASSED' if all_passed else '❌ FAILED'}")
    
    return all_passed

if __name__ == "__main__":
    success = test_screenshot_capture()
    exit(0 if success else 1)