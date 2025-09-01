#!/usr/bin/env python3
"""
Integration test for post-scroll business extraction
Tests that businesses like Perceptive Painting LLC are successfully extracted after scrolling
"""

import asyncio
import json
import time
import sqlite3
from typing import Dict, List
import httpx


class PostScrollExtractionTest:
    """Integration test for post-scroll business extraction"""
    
    def __init__(self):
        self.base_url = "http://localhost:8000"
        self.client = httpx.AsyncClient(timeout=300.0)  # 5 minute timeout for long searches
        
    async def cleanup_database(self):
        """Clean up test data from previous runs"""
        conn = get_database_connection()
        try:
            # Delete any existing leads for this test
            conn.execute("DELETE FROM leads WHERE location LIKE '%Papillion%' OR business_name LIKE '%Perceptive Painting%'")
            conn.execute("DELETE FROM jobs WHERE query LIKE '%painter%' AND location LIKE '%Papillion%'")
            conn.commit()
            print("✅ Database cleaned up")
        except Exception as e:
            print(f"⚠️ Database cleanup warning: {e}")
        finally:
            conn.close()
    
    async def test_post_scroll_perceptive_painting_extraction(self):
        """Test that Perceptive Painting LLC is found and saved after scrolling"""
        print("\n" + "="*80)
        print("🧪 INTEGRATION TEST: Post-Scroll Extraction for Perceptive Painting LLC")
        print("="*80)
        
        # Clean up database first
        await self.cleanup_database()
        
        # 1. Start the search job
        search_params = {
            "query": "painters in Papillion",
            "location": "Papillion", 
            "industry": "painting",
            "limit": 5,  # Small limit to force scrolling
            "min_rating": 4.0,
            "min_reviews": 5,
            "requires_website": False,  # We want businesses without websites
            "browser_mode": "headless",
            "enable_click_through": True
        }
        
        print(f"🚀 Starting search job with params:")
        for key, value in search_params.items():
            print(f"   {key}: {value}")
        
        # Start the job
        response = await self.client.post(f"{self.base_url}/start-job", json=search_params)
        assert response.status_code == 200, f"Failed to start job: {response.text}"
        
        job_data = response.json()
        job_id = job_data["job_id"]
        print(f"✅ Job started with ID: {job_id}")
        
        # 2. Monitor the job and wait for completion
        max_wait_time = 240  # 4 minutes max wait
        start_time = time.time()
        found_perceptive_painting = False
        scrolling_detected = False
        
        while time.time() - start_time < max_wait_time:
            # Get job status and logs
            status_response = await self.client.get(f"{self.base_url}/jobs/{job_id}/status")
            logs_response = await self.client.get(f"{self.base_url}/jobs/{job_id}/logs?tail=50")
            
            if status_response.status_code == 200 and logs_response.status_code == 200:
                status = status_response.json()
                logs = logs_response.text
                
                # Check for scrolling activity
                if "Scrolled results panel" in logs or "scroll" in logs.lower():
                    if not scrolling_detected:
                        scrolling_detected = True
                        print("📜 SCROLLING DETECTED - monitoring for post-scroll extraction...")
                
                # Check for Perceptive Painting LLC
                if "Perceptive Painting LLC" in logs:
                    found_perceptive_painting = True
                    print("🎯 FOUND: Perceptive Painting LLC in logs!")
                
                # Check if job completed
                if status.get("status") in ["completed", "failed"]:
                    print(f"🏁 Job completed with status: {status.get('status')}")
                    break
                    
                print(f"⏳ Job status: {status.get('status')} - waiting... ({int(time.time() - start_time)}s)")
                
            await asyncio.sleep(3)  # Check every 3 seconds
        
        # 3. Get final results from database
        conn = get_database_connection()
        try:
            # Check if Perceptive Painting LLC was saved
            cursor = conn.execute("""
                SELECT business_name, rating, review_count, phone, website_url, has_website, location
                FROM leads 
                WHERE business_name LIKE '%Perceptive Painting%' 
                   OR business_name = 'Perceptive Painting LLC'
                ORDER BY created_at DESC
                LIMIT 1
            """)
            perceptive_painting_record = cursor.fetchone()
            
            # Get all leads from this job
            cursor = conn.execute("""
                SELECT business_name, rating, review_count, has_website
                FROM leads 
                WHERE job_id = ? OR location LIKE '%Papillion%'
                ORDER BY created_at DESC
            """, (job_id,))
            all_leads = cursor.fetchall()
            
        finally:
            conn.close()
        
        # 4. Validate results
        print(f"\n📊 RESULTS ANALYSIS:")
        print(f"   Scrolling detected: {scrolling_detected}")
        print(f"   Found in logs: {found_perceptive_painting}")
        print(f"   Total leads found: {len(all_leads) if all_leads else 0}")
        
        if all_leads:
            print(f"   All leads:")
            for lead in all_leads:
                business_name, rating, review_count, has_website = lead
                print(f"     - {business_name} (Rating: {rating}, Reviews: {review_count}, Website: {has_website})")
        
        # Critical assertions
        assert scrolling_detected, "❌ FAIL: No scrolling was detected during the search"
        assert found_perceptive_painting, "❌ FAIL: Perceptive Painting LLC was not found in logs"
        assert perceptive_painting_record is not None, "❌ FAIL: Perceptive Painting LLC was not saved to database"
        
        if perceptive_painting_record:
            business_name, rating, review_count, phone, website_url, has_website, location = perceptive_painting_record
            print(f"\n✅ SUCCESS: Perceptive Painting LLC saved to database!")
            print(f"   Business Name: {business_name}")
            print(f"   Rating: {rating}")
            print(f"   Reviews: {review_count}")
            print(f"   Phone: {phone}")
            print(f"   Website: {website_url}")
            print(f"   Has Website: {has_website}")
            print(f"   Location: {location}")
            
            # Validate the data quality
            assert rating >= 4.0, f"❌ FAIL: Rating {rating} is below minimum 4.0"
            assert review_count >= 5, f"❌ FAIL: Review count {review_count} is below minimum 5"
            assert has_website is False, "❌ FAIL: Business should not have website (requires_website=False)"
        
        print(f"\n🎉 INTEGRATION TEST PASSED!")
        print(f"   ✅ Scrolling occurred during search")  
        print(f"   ✅ Perceptive Painting LLC was detected in logs")
        print(f"   ✅ Perceptive Painting LLC was saved to database")
        print(f"   ✅ Data meets quality requirements")
        return True
        
    async def cleanup(self):
        """Clean up resources"""
        await self.client.aclose()


async def run_integration_test():
    """Run the integration test"""
    test = PostScrollExtractionTest()
    try:
        success = await test.test_post_scroll_perceptive_painting_extraction()
        return success
    finally:
        await test.cleanup()


if __name__ == "__main__":
    print("🚀 Starting Post-Scroll Extraction Integration Test...")
    success = asyncio.run(run_integration_test())
    if success:
        print("\n🎊 All tests passed! Post-scroll extraction is working correctly.")
        exit(0)
    else:
        print("\n💥 Tests failed! Post-scroll extraction needs debugging.")
        exit(1)