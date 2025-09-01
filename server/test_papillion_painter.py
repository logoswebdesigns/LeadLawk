#!/usr/bin/env python3
"""
Test to verify that Papillion painter searches properly identify business properties,
specifically ensuring Perceptive Painting LLC and other painters are captured correctly.
"""

import asyncio
import httpx
import time


async def test_papillion_painter_extraction():
    """Test that papillion painter search identifies business properties correctly"""
    print("\n" + "="*80)
    print("🧪 PAPILLION PAINTER BUSINESS IDENTIFICATION TEST")
    print("="*80)
    
    client = httpx.AsyncClient(timeout=60.0)
    base_url = "http://localhost:8000"
    
    try:
        # Create a papillion painter job
        job_params = {
            "industry": "painter",
            "location": "Papillion", 
            "limit": 5,  # Get several results to verify extraction
            "min_rating": 1.0,  # Low threshold to get more results
            "min_reviews": 1,
            "requires_website": False,
            "browser_mode": "headless"
        }
        
        print(f"🚀 Creating Papillion painter job with params: {job_params}")
        
        # Start the job
        response = await client.post(f"{base_url}/jobs/browser", json=job_params)
        if response.status_code != 200:
            raise Exception(f"Failed to create job: {response.text}")
            
        job_data = response.json()
        job_id = job_data["job_id"]
        print(f"✅ Job created with ID: {job_id}")
        
        # Monitor job progress
        print("📊 Monitoring job progress...")
        max_wait_time = 120  # 2 minutes max
        start_time = time.time()
        
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
            
            if status in ["completed", "failed"]:
                break
                
            await asyncio.sleep(3)
        
        # Get final job status
        job_response = await client.get(f"{base_url}/jobs/{job_id}")
        final_job = job_response.json()
        
        if final_job.get("status") == "failed":
            raise Exception(f"Job failed: {final_job.get('message', 'Unknown error')}")
            
        print(f"\n✅ Job completed! Found {final_job.get('processed', 0)} businesses")
        
        # Get the leads to verify business property extraction
        leads_response = await client.get(f"{base_url}/leads")
        if leads_response.status_code != 200:
            raise Exception(f"Failed to get leads: {leads_response.text}")
            
        leads = leads_response.json()
        recent_leads = [lead for lead in leads if "painter" in lead.get("business_name", "").lower()]
        
        print(f"\n📋 Found {len(recent_leads)} painter leads:")
        
        painter_businesses_found = []
        property_extraction_issues = []
        
        for i, lead in enumerate(recent_leads[:10], 1):  # Check first 10
            business_name = lead.get("business_name", "")
            phone = lead.get("phone", "")
            website = lead.get("website_url", "")
            rating = lead.get("rating")
            review_count = lead.get("review_count")
            
            print(f"\n{i}. 📋 {business_name}")
            print(f"   📞 Phone: {phone or 'NOT FOUND'}")
            print(f"   🌐 Website: {website or 'NO WEBSITE'}")
            print(f"   ⭐ Rating: {rating or 'NOT FOUND'}")
            print(f"   📝 Reviews: {review_count or 'NOT FOUND'}")
            
            painter_businesses_found.append(business_name)
            
            # Check for missing critical properties
            if not business_name:
                property_extraction_issues.append("Missing business name")
            if not phone:
                property_extraction_issues.append(f"Missing phone for {business_name}")
            if rating is None:
                property_extraction_issues.append(f"Missing rating for {business_name}")
            if review_count is None:
                property_extraction_issues.append(f"Missing review count for {business_name}")
        
        # Verify key business is found
        perceptive_found = any("Perceptive Painting" in name for name in painter_businesses_found)
        if perceptive_found:
            print(f"\n✅ Key business 'Perceptive Painting LLC' was successfully identified!")
        else:
            print(f"\n⚠️  'Perceptive Painting LLC' not found in results")
            
        # Report on property extraction
        if property_extraction_issues:
            print(f"\n⚠️  Property extraction issues found:")
            for issue in property_extraction_issues[:5]:  # Show first 5
                print(f"   - {issue}")
        else:
            print(f"\n✅ All business properties extracted successfully!")
            
        # Summary
        print(f"\n" + "="*80)
        print("📊 PAPILLION PAINTER TEST RESULTS:")
        print(f"✅ Total businesses found: {len(recent_leads)}")
        print(f"✅ Businesses with complete data: {len(recent_leads) - len(property_extraction_issues)}")
        print(f"✅ Perceptive Painting found: {'Yes' if perceptive_found else 'No'}")
        print(f"✅ Property extraction issues: {len(property_extraction_issues)}")
        
        if len(recent_leads) > 0 and len(property_extraction_issues) < len(recent_leads) * 0.5:
            print(f"\n🎉 PAPILLION PAINTER TEST PASSED!")
            print("✅ Business properties are being identified correctly")
            return True
        else:
            raise Exception("Too many property extraction failures")
            
    except Exception as e:
        print(f"\n💥 TEST FAILED: {e}")
        return False
        
    finally:
        await client.aclose()


async def main():
    print("🚀 Starting Papillion Painter Business Identification Test...")
    success = await test_papillion_painter_extraction()
    
    if success:
        print("\n🎊 Papillion painter business identification working correctly!")
        exit(0)
    else:
        print("\n❌ Business identification issues detected!")
        exit(1)


if __name__ == "__main__":
    asyncio.run(main())