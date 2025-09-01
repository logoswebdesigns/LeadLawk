#!/usr/bin/env python3
"""Test script to verify compact listing website extraction is working"""

import requests
import json
import time

def test_dentist_search():
    """Test the 'dentist omaha' search to verify compact listing extraction"""
    
    print("🔍 Testing compact listing website extraction with 'dentist omaha' search")
    print("="*60)
    
    # Start a search job
    url = "http://localhost:8000/api/browser/start"
    
    payload = {
        "query": "dentist omaha",
        "limit": 10,
        "min_rating": 0,
        "min_reviews": 0,
        "requires_website": None,  # Don't filter by website - we want to see all businesses
        "recent_review_months": None,
        "min_photos": None,
        "min_description_length": None,
        "enable_click_through": True,  # Enable click-through to test compact listing extraction
        "enable_pagespeed": False
    }
    
    print(f"📤 Sending request to: {url}")
    print(f"   Query: {payload['query']}")
    print(f"   Limit: {payload['limit']}")
    print(f"   Click-through enabled: {payload['enable_click_through']}")
    print()
    
    try:
        response = requests.post(url, json=payload)
        response.raise_for_status()
        
        job_data = response.json()
        job_id = job_data.get("job_id")
        
        if not job_id:
            print("❌ No job_id received from server")
            return
        
        print(f"✅ Job started: {job_id}")
        print()
        
        # Poll for job completion
        status_url = f"http://localhost:8000/api/browser/status/{job_id}"
        max_attempts = 60  # 5 minutes max
        attempt = 0
        
        while attempt < max_attempts:
            attempt += 1
            time.sleep(5)
            
            status_response = requests.get(status_url)
            if status_response.status_code == 200:
                status_data = status_response.json()
                status = status_data.get("status")
                
                print(f"   Status: {status} (attempt {attempt}/{max_attempts})")
                
                if status == "completed":
                    print(f"✅ Job completed successfully!")
                    print()
                    
                    # Get the leads that were found
                    leads_url = f"http://localhost:8000/api/leads?job_id={job_id}"
                    leads_response = requests.get(leads_url)
                    
                    if leads_response.status_code == 200:
                        leads = leads_response.json()
                        
                        print(f"📊 Results Summary:")
                        print(f"   Total businesses found: {len(leads)}")
                        print()
                        
                        # Analyze website detection
                        with_website = 0
                        without_website = 0
                        compact_listings = []
                        
                        for lead in leads:
                            has_website = lead.get("website_url") is not None
                            if has_website:
                                with_website += 1
                            else:
                                without_website += 1
                            
                            # Check if this might have been a compact listing
                            # (we can't know for sure without seeing the extractor logs)
                            print(f"   • {lead.get('business_name', 'Unknown')}")
                            print(f"     Website: {lead.get('website_url', 'None')}")
                            print(f"     Phone: {lead.get('phone', 'None')}")
                            print()
                        
                        print(f"📈 Website Detection Statistics:")
                        print(f"   Businesses with websites: {with_website}")
                        print(f"   Businesses without websites: {without_website}")
                        print()
                        
                        if with_website > 0:
                            print("✅ Website extraction appears to be working!")
                            print("   (Found websites for some businesses)")
                        else:
                            print("⚠️ No websites found - this might indicate an issue")
                            print("   (Though some dentists genuinely don't have websites)")
                    
                    break
                    
                elif status == "failed":
                    error = status_data.get("error", "Unknown error")
                    print(f"❌ Job failed: {error}")
                    break
                    
                elif status == "cancelled":
                    print(f"⚠️ Job was cancelled")
                    break
        
        if attempt >= max_attempts:
            print(f"⏱️ Job timed out after {max_attempts} attempts")
    
    except requests.exceptions.RequestException as e:
        print(f"❌ Request error: {e}")
    except Exception as e:
        print(f"❌ Unexpected error: {e}")

if __name__ == "__main__":
    test_dentist_search()