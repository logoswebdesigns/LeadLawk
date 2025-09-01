#!/usr/bin/env python3
"""
Integration test to prevent job data and navigation regressions
"""

import asyncio
import json
import time
from typing import Dict
import httpx


class JobIntegrationTest:
    """Test job creation, data integrity, and API endpoints"""
    
    def __init__(self):
        self.base_url = "http://localhost:8000"
        self.client = httpx.AsyncClient(timeout=30.0)
        
    async def test_job_data_integrity(self):
        """Test that job data includes all required fields"""
        print("\n" + "="*80)
        print("🧪 INTEGRATION TEST: Job Data Integrity")
        print("="*80)
        
        # 1. Create a job with specific parameters
        job_params = {
            "industry": "painter",
            "location": "Papillion",
            "limit": 1,
            "min_rating": 4.0,
            "min_reviews": 1,
            "requires_website": False,
            "browser_mode": "headless"
        }
        
        print(f"🚀 Creating job with params: {job_params}")
        
        # Start the job
        response = await self.client.post(f"{self.base_url}/jobs/browser", json=job_params)
        if response.status_code != 200:
            raise Exception(f"Failed to create job: {response.text}")
        
        job_data = response.json()
        job_id = job_data["job_id"]
        print(f"✅ Job created with ID: {job_id}")
        
        # 2. Verify job appears in jobs list with correct data
        await asyncio.sleep(1)  # Allow job to initialize
        
        jobs_response = await self.client.get(f"{self.base_url}/jobs")
        if jobs_response.status_code != 200:
            raise Exception(f"Failed to get jobs: {jobs_response.text}")
        
        jobs = jobs_response.json()
        target_job = None
        for job in jobs:
            if job.get("id") == job_id:
                target_job = job
                break
                
        if target_job is None:
            raise Exception(f"Job {job_id} not found in jobs list")
        print(f"✅ Job found in jobs list: {target_job}")
        
        # 3. Validate job data contains required fields
        required_fields = ["id", "status", "industry", "location", "query", "limit"]
        for field in required_fields:
            if field not in target_job:
                raise Exception(f"Missing required field: {field}")
            if target_job[field] is None:
                raise Exception(f"Field {field} is null")
            
        # Validate specific values
        if target_job["industry"] != "painter":
            raise Exception(f"Wrong industry: {target_job['industry']}")
        if target_job["location"] != "Papillion":
            raise Exception(f"Wrong location: {target_job['location']}")
        if target_job["limit"] != 1:
            raise Exception(f"Wrong limit: {target_job['limit']}")
        
        print("✅ All required fields present and correct")
        
        # 4. Test individual job endpoint
        job_response = await self.client.get(f"{self.base_url}/jobs/{job_id}")
        if job_response.status_code != 200:
            raise Exception(f"Failed to get individual job: {job_response.text}")
        
        individual_job = job_response.json()
        if individual_job["id"] != job_id:
            raise Exception("Individual job ID mismatch")
        if individual_job["industry"] != "painter":
            raise Exception("Individual job industry mismatch")
        
        print("✅ Individual job endpoint working correctly")
        
        # 5. Test job logs endpoint (should not be 404)
        logs_response = await self.client.get(f"{self.base_url}/jobs/{job_id}/logs?tail=10")
        if logs_response.status_code != 200:
            raise Exception(f"Job logs endpoint returned 404: {logs_response.text}")
        
        logs_data = logs_response.json()
        if "lines" not in logs_data:
            raise Exception("Logs response missing 'lines' field")
        
        print("✅ Job logs endpoint working correctly")
        
        # 6. Test job screenshots endpoint (should not be 404)
        screenshots_response = await self.client.get(f"{self.base_url}/jobs/{job_id}/screenshots")
        if screenshots_response.status_code != 200:
            raise Exception(f"Job screenshots endpoint returned 404: {screenshots_response.text}")
        
        screenshots_data = screenshots_response.json()
        if not isinstance(screenshots_data, list):
            raise Exception("Screenshots response should be a list")
        
        print("✅ Job screenshots endpoint working correctly")
        
        return True
        
    async def test_flutter_job_card_data(self):
        """Test the exact data format Flutter job cards expect"""
        print("\n" + "="*80)
        print("🧪 FLUTTER INTEGRATION TEST: Job Card Data Format")
        print("="*80)
        
        # Create a job
        job_params = {
            "industry": "electrician",
            "location": "Denver",
            "limit": 2,
            "min_rating": 4.5,
            "min_reviews": 10
        }
        
        response = await self.client.post(f"{self.base_url}/jobs/browser", json=job_params)
        if response.status_code != 200:
            raise Exception(f"Failed to create job: {response.text}")
        
        job_id = response.json()["job_id"]
        await asyncio.sleep(1)
        
        # Get job from list
        jobs_response = await self.client.get(f"{self.base_url}/jobs")
        jobs = jobs_response.json()
        
        target_job = next((job for job in jobs if job["id"] == job_id), None)
        if target_job is None:
            raise Exception(f"Job {job_id} not found in jobs list")
        
        # Test Flutter job card title generation logic
        industry = target_job.get("industry", "Business")
        location = target_job.get("location", "Unknown")
        expected_title = f"{industry} in {location}"
        
        print(f"Flutter job card title: '{expected_title}'")
        
        # Verify it's not "Business in Unknown"
        if industry == "Business":
            raise Exception(f"Industry should not default to 'Business', got: {industry}")
        if location == "Unknown":
            raise Exception(f"Location should not default to 'Unknown', got: {location}")
        if expected_title != "electrician in Denver":
            raise Exception(f"Expected 'electrician in Denver', got: '{expected_title}'")
        
        print("✅ Flutter job card data format correct")
        
        return True
        
    async def test_job_id_navigation_urls(self):
        """Test that job IDs work correctly in navigation URLs"""
        print("\n" + "="*80)
        print("🧪 NAVIGATION TEST: Job ID URL Generation")
        print("="*80)
        
        # Create multiple jobs to test
        jobs_created = []
        for i in range(3):
            params = {
                "industry": f"test_industry_{i}",
                "location": f"test_location_{i}",
                "limit": 1
            }
            
            response = await self.client.post(f"{self.base_url}/jobs/browser", json=params)
            if response.status_code != 200:
                raise Exception(f"Failed to create job {i}: {response.text}")
            
            job_id = response.json()["job_id"]
            jobs_created.append(job_id)
            
        await asyncio.sleep(2)  # Allow jobs to initialize
        
        # Test each job ID in navigation-like URLs
        for job_id in jobs_created:
            # Test Flutter navigation URLs would work
            if job_id is None:
                raise Exception("Job ID should not be None")
            if job_id == "":
                raise Exception("Job ID should not be empty")
            if len(job_id) <= 10:
                raise Exception(f"Job ID seems too short: {job_id}")
            
            # Simulate Flutter navigation URL construction
            flutter_url = f"/browser/monitor/{job_id}"
            print(f"Flutter navigation URL: {flutter_url}")
            
            # Test actual API endpoints the navigation would use
            endpoints_to_test = [
                f"/jobs/{job_id}",
                f"/jobs/{job_id}/logs?tail=10",
                f"/jobs/{job_id}/screenshots"
            ]
            
            for endpoint in endpoints_to_test:
                response = await self.client.get(f"{self.base_url}{endpoint}")
                if response.status_code != 200:
                    raise Exception(f"Navigation endpoint {endpoint} failed: {response.status_code}")
                
        print(f"✅ All {len(jobs_created)} job IDs work correctly for navigation")
        
        return True
    
    async def cleanup(self):
        """Clean up resources"""
        await self.client.aclose()


async def run_all_tests():
    """Run all integration tests"""
    test = JobIntegrationTest()
    try:
        await test.test_job_data_integrity()
        await test.test_flutter_job_card_data()
        await test.test_job_id_navigation_urls()
        
        print(f"\n🎉 ALL INTEGRATION TESTS PASSED!")
        print("✅ Job data integrity maintained")
        print("✅ Flutter job cards will display correctly")
        print("✅ Navigation URLs work properly")
        print("✅ No more 404 errors or 'Business in Unknown' issues")
        
        return True
        
    except Exception as e:
        print(f"\n💥 TEST FAILED: {e}")
        return False
        
    finally:
        await test.cleanup()


if __name__ == "__main__":
    print("🚀 Starting Job Integration Tests to Prevent Regression...")
    success = asyncio.run(run_all_tests())
    if success:
        print("\n🎊 All regression tests passed! Issues are fixed and prevented.")
        exit(0)
    else:
        print("\n💥 Tests failed! Regressions detected.")
        exit(1)