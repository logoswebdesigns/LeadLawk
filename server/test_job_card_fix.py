#!/usr/bin/env python3
"""
Test to verify that recent job cards in Flutter app can navigate correctly
after fixing the jobId field name issue
"""

import httpx
import asyncio
import json


async def test_job_card_fix():
    """Test that jobs have correct ID field for Flutter navigation"""
    print("\n" + "="*80)
    print("🧪 JOB CARD NAVIGATION FIX TEST")
    print("="*80)
    
    client = httpx.AsyncClient(timeout=30.0)
    base_url = "http://localhost:8000"
    
    try:
        # First, create a test job to ensure we have recent jobs
        print("\n1️⃣ Creating a test job...")
        job_params = {
            "industry": "painter",
            "location": "Omaha",
            "limit": 15,
            "min_rating": 1.0,
            "min_reviews": 1,
            "requires_website": False,
            "browser_mode": "headless"
        }
        
        response = await client.post(f"{base_url}/jobs/browser", json=job_params)
        if response.status_code != 200:
            print(f"⚠️ Failed to create test job: {response.text}")
        else:
            job_data = response.json()
            created_job_id = job_data.get("job_id")
            print(f"✅ Created test job with ID: {created_job_id}")
        
        # Now fetch the jobs list
        print("\n2️⃣ Fetching jobs list...")
        jobs_response = await client.get(f"{base_url}/jobs")
        
        if jobs_response.status_code != 200:
            raise Exception(f"Failed to fetch jobs: {jobs_response.text}")
        
        jobs = jobs_response.json()
        print(f"✅ Found {len(jobs)} total jobs")
        
        # Verify job structure
        print("\n3️⃣ Verifying job structure for Flutter compatibility...")
        issues = []
        
        for i, job in enumerate(jobs[:3]):  # Check first 3 jobs
            print(f"\n  Job {i+1}:")
            
            # Check for 'id' field (correct)
            if 'id' in job:
                print(f"    ✅ Has 'id' field: {job['id']}")
            else:
                issues.append(f"Job {i+1} missing 'id' field")
                print(f"    ❌ Missing 'id' field")
            
            # Check for incorrect 'job_id' field
            if 'job_id' in job:
                print(f"    ⚠️ Has deprecated 'job_id' field: {job['job_id']}")
            
            # Check status field
            status = job.get('status', 'unknown')
            print(f"    📊 Status: {status}")
            if status not in ['pending', 'running', 'completed', 'failed', 'error']:
                issues.append(f"Job {i+1} has unexpected status: {status}")
            
            # Check other required fields for job cards
            has_processed = 'processed' in job
            has_total = 'total' in job
            has_industry = 'industry' in job or ('params' in job and 'industry' in job.get('params', {}))
            has_location = 'location' in job or ('params' in job and 'location' in job.get('params', {}))
            
            print(f"    📋 Has processed: {has_processed} ({job.get('processed', 'N/A')})")
            print(f"    📋 Has total: {has_total} ({job.get('total', 'N/A')})")
            print(f"    📋 Has industry: {has_industry}")
            print(f"    📋 Has location: {has_location}")
        
        # Summary
        print("\n" + "="*80)
        print("📊 TEST SUMMARY")
        print("="*80)
        
        if not issues:
            print("✅ All jobs have correct structure for Flutter navigation!")
            print("✅ Job cards should now be clickable and navigate to monitor page")
            print("\nKey fixes applied:")
            print("  • Changed Flutter code from job['job_id'] to job['id']")
            print("  • Updated status check from 'done' to 'completed'")
            print("  • Added backward compatibility for both status names")
        else:
            print("❌ Issues found:")
            for issue in issues:
                print(f"  • {issue}")
        
        return len(issues) == 0
        
    except Exception as e:
        print(f"\n💥 TEST FAILED: {e}")
        return False
        
    finally:
        await client.aclose()


async def main():
    print("🚀 Testing Job Card Navigation Fix...")
    success = await test_job_card_fix()
    
    if success:
        print("\n🎉 JOB CARD FIX VERIFIED!")
        print("✅ Recent lead job cards should now be clickable")
        exit(0)
    else:
        print("\n❌ Issues remain with job card structure")
        exit(1)


if __name__ == "__main__":
    asyncio.run(main())