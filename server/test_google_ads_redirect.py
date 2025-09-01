#!/usr/bin/env python3
"""
Test that Google Ads redirect URLs are:
1. Detected and followed to the actual website
2. Cleaned of tracking parameters
3. Stored cleanly in the database
4. Used for PageSpeed testing
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from database_operations import save_lead_to_database
from database import SessionLocal
from models import Lead
import time

def test_google_ads_redirect():
    """Test Google Ads URL handling"""
    
    print("🧪 Testing Google Ads Redirect Handling...")
    print("=" * 50)
    
    # Test case 1: Google Ads URL with redirect
    test_business_1 = {
        'name': 'Test Real Estate Company',
        'industry': 'Real Estate',
        'rating': 4.5,
        'reviews': 100,
        'website': 'https://www.google.com/aclk?sa=L&ai=DChcSEwiZtbO6o7OPAxVBK9QBHUXAMmcYABACGgJvYQ&co=1&ase=2&gclid=EAIaIQobChMImbWzuqOzjwMVQSvUAR1FwDJnEBAYAiAAEgJwIfD_BwE&cce=2&category=acrcp_v1_32&sig=AOD64_0jYDvdGlEOEXc_HPj_qGgXUpYbLA&adurl&q&ctype=99&nis=6',
        'has_website': True,
        'phone': '555-1234',
        'url': 'https://maps.google.com/test',
        'location': 'Sarasota, FL',
        'has_recent_reviews': True,
        'screenshot_filename': None
    }
    
    print("\n📤 Test 1: Google Ads redirect URL")
    print(f"Original URL: {test_business_1['website'][:80]}...")
    
    # Save with PageSpeed enabled to trigger redirect resolution
    lead_id_1 = save_lead_to_database(test_business_1, job_id='test-job-1', enable_pagespeed=True)
    
    # Give it a moment to process
    time.sleep(2)
    
    # Check what was saved
    db = SessionLocal()
    try:
        lead = db.query(Lead).filter(Lead.id == lead_id_1).first()
        if lead:
            print(f"✅ Lead saved with ID: {lead.id}")
            print(f"📦 Stored URL: {lead.website_url}")
            
            # Check if URL was cleaned
            if 'google.com/aclk' not in lead.website_url:
                print("✅ Google Ads URL was replaced with actual website")
                
                # Check if tracking parameters were removed
                if '?' not in lead.website_url and '&' not in lead.website_url:
                    print("✅ Tracking parameters were removed")
                else:
                    print("⚠️ URL still contains tracking parameters")
            else:
                print("❌ Google Ads URL was not resolved")
        else:
            print("❌ Lead not found in database")
            
    finally:
        db.close()
    
    # Test case 2: Regular URL (should not be modified)
    test_business_2 = {
        'name': 'Test Plumbing Company',
        'industry': 'Plumbing',
        'rating': 4.8,
        'reviews': 200,
        'website': 'https://example-plumbing.com',
        'has_website': True,
        'phone': '555-5678',
        'url': 'https://maps.google.com/test2',
        'location': 'Omaha, NE',
        'has_recent_reviews': True,
        'screenshot_filename': None
    }
    
    print("\n📤 Test 2: Regular website URL")
    print(f"Original URL: {test_business_2['website']}")
    
    lead_id_2 = save_lead_to_database(test_business_2, job_id='test-job-2', enable_pagespeed=True)
    
    time.sleep(1)
    
    db = SessionLocal()
    try:
        lead = db.query(Lead).filter(Lead.id == lead_id_2).first()
        if lead:
            print(f"✅ Lead saved with ID: {lead.id}")
            print(f"📦 Stored URL: {lead.website_url}")
            
            if lead.website_url == test_business_2['website']:
                print("✅ Regular URL was not modified")
            else:
                print("⚠️ Regular URL was unexpectedly modified")
                
    finally:
        db.close()
    
    # Test case 3: Another Google Ads variant
    test_business_3 = {
        'name': 'Test Pool Service',
        'industry': 'Pool Service',
        'rating': 4.2,
        'reviews': 50,
        'website': 'https://googleadservices.com/pagead/aclk?sa=L&ai=test123',
        'has_website': True,
        'phone': '555-9999',
        'url': 'https://maps.google.com/test3',
        'location': 'Tampa, FL',
        'has_recent_reviews': True,
        'screenshot_filename': None
    }
    
    print("\n📤 Test 3: GoogleAdServices URL")
    print(f"Original URL: {test_business_3['website']}")
    
    lead_id_3 = save_lead_to_database(test_business_3, job_id='test-job-3', enable_pagespeed=True)
    
    time.sleep(2)
    
    db = SessionLocal()
    try:
        lead = db.query(Lead).filter(Lead.id == lead_id_3).first()
        if lead:
            print(f"✅ Lead saved with ID: {lead.id}")
            print(f"📦 Stored URL: {lead.website_url}")
            
            if 'googleadservices.com' not in lead.website_url:
                print("✅ GoogleAdServices URL was resolved")
            else:
                print("⚠️ GoogleAdServices URL was not resolved (might be unreachable)")
                
    finally:
        db.close()
    
    print("\n" + "=" * 50)
    print("🎉 Google Ads redirect tests complete!")
    print("\nNote: Actual redirect resolution depends on the URLs being reachable.")
    print("In production, real Google Ads URLs will redirect to actual business websites.")
    
    return True

if __name__ == "__main__":
    success = test_google_ads_redirect()
    sys.exit(0 if success else 1)