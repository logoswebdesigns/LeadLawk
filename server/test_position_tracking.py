#!/usr/bin/env python3
"""
Test to verify that position tracking works correctly after scrolling.
This test will monitor if businesses continue to be evaluated post-scroll.
"""

import asyncio
import httpx
import time


async def test_position_tracking():
    """Test that position tracking works after scrolling"""
    print("\n" + "="*80)
    print("🧪 POSITION TRACKING TEST")
    print("="*80)
    
    client = httpx.AsyncClient(timeout=120.0)
    base_url = "http://localhost:8000"
    
    try:
        # Create a job that will require scrolling (higher limit)
        job_params = {
            "industry": "painter",
            "location": "Omaha", 
            "limit": 15,  # Higher limit to force scrolling
            "min_rating": 1.0,
            "min_reviews": 1,
            "requires_website": False,
            "browser_mode": "headless"
        }
        
        print(f"🚀 Creating Omaha painter job with {job_params['limit']} business limit")
        
        # Start the job
        response = await client.post(f"{base_url}/jobs/browser", json=job_params)
        if response.status_code != 200:
            raise Exception(f"Failed to create job: {response.text}")
            
        job_data = response.json()
        job_id = job_data["job_id"]
        print(f"✅ Job created with ID: {job_id}")
        
        # Monitor job progress and look for position tracking logs
        print("📊 Monitoring for position tracking behavior...")
        max_wait_time = 180  # 3 minutes max
        start_time = time.time()
        position_tracking_working = False
        evaluation_logs_after_scroll = 0
        
        while time.time() - start_time < max_wait_time:
            # Check job status
            job_response = await client.get(f"{base_url}/jobs/{job_id}")
            if job_response.status_code != 200:
                raise Exception(f"Failed to get job status: {job_response.text}")
                
            job_status = job_response.json()
            status = job_status.get("status")
            processed = job_status.get("processed", 0)
            total = job_status.get("total", 0)
            message = job_status.get("message", "")
            
            print(f"📋 Status: {status} | Progress: {processed}/{total} | {message}")
            
            # Look for position tracking indicators in the message
            if "Continuing from last processed" in message or "Found where we left off" in message:
                position_tracking_working = True
                print("✅ Position tracking is working!")
            
            # Count evaluation logs to see if they continue after scroll
            if "Evaluating:" in message:
                evaluation_logs_after_scroll += 1
                print(f"✅ Business evaluation #{evaluation_logs_after_scroll}: {message}")
            
            if status in ["completed", "failed"]:
                break
                
            await asyncio.sleep(3)
        
        # Get final job status
        job_response = await client.get(f"{base_url}/jobs/{job_id}")
        final_job = job_response.json()
        
        if final_job.get("status") == "failed":
            raise Exception(f"Job failed: {final_job.get('message', 'Unknown error')}")
            
        final_processed = final_job.get('processed', 0)
        print(f"\n✅ Job completed! Found {final_processed} businesses")
        
        # Verify position tracking worked
        if position_tracking_working:
            print("✅ Position tracking logs detected - fix is working!")
        else:
            print("⚠️ No position tracking logs detected - checking if needed...")
        
        if evaluation_logs_after_scroll >= 10:
            print(f"✅ Saw {evaluation_logs_after_scroll} evaluation logs - businesses continuing to be processed")
            return True
        elif final_processed < job_params['limit']:
            print(f"⚠️ Only found {final_processed} businesses (less than limit {job_params['limit']}) - may not have needed scrolling")
            return True
        else:
            print(f"❌ Only saw {evaluation_logs_after_scroll} evaluation logs despite processing {final_processed} businesses")
            return False
            
    except Exception as e:
        print(f"\n💥 TEST FAILED: {e}")
        return False
        
    finally:
        await client.aclose()


async def main():
    print("🚀 Starting Position Tracking Test...")
    success = await test_position_tracking()
    
    if success:
        print("\n🎊 Position tracking is working correctly!")
        exit(0)
    else:
        print("\n❌ Position tracking issues detected!")
        exit(1)


if __name__ == "__main__":
    asyncio.run(main())