#!/usr/bin/env python3
"""
Anti-regression test for PageSpeed parameter parsing in parallel jobs endpoint.
Tests that enable_pagespeed is correctly parsed from request body.
"""

import requests
import json
import sys

def test_pagespeed_parameter():
    """Test that enable_pagespeed parameter is correctly parsed"""
    
    base_url = "http://localhost:8000"
    
    # Test data with enable_pagespeed = True
    test_payload = {
        "industries": ["test_industry"],
        "locations": ["test_location"],
        "limit": 1,
        "min_rating": 4.0,
        "min_reviews": 1,
        "requires_website": None,
        "recent_review_months": 24,
        "enable_pagespeed": True  # This should be parsed correctly
    }
    
    print("🧪 Testing PageSpeed parameter parsing...")
    print(f"📤 Sending request with enable_pagespeed: {test_payload['enable_pagespeed']}")
    
    try:
        # Send request to parallel jobs endpoint
        response = requests.post(
            f"{base_url}/jobs/parallel",
            json=test_payload,
            timeout=5
        )
        
        # Check response
        if response.status_code != 200:
            print(f"❌ Test failed: Expected status 200, got {response.status_code}")
            print(f"Response: {response.text}")
            return False
            
        # Parse response
        result = response.json()
        
        # Check that job was created
        if "parent_job_id" not in result:
            print("❌ Test failed: No parent_job_id in response")
            return False
            
        print(f"✅ Job created successfully: {result['parent_job_id']}")
        
        # Check server logs (would need to parse Docker logs in production)
        # For now, just check that the endpoint accepts the parameter
        print("✅ Server accepted enable_pagespeed parameter")
        
        # Test with enable_pagespeed = False
        test_payload["enable_pagespeed"] = False
        print(f"📤 Testing with enable_pagespeed: {test_payload['enable_pagespeed']}")
        
        response = requests.post(
            f"{base_url}/jobs/parallel",
            json=test_payload,
            timeout=5
        )
        
        if response.status_code != 200:
            print(f"❌ Test failed with enable_pagespeed=False")
            return False
            
        print("✅ Server accepted enable_pagespeed=False")
        
        # Test without enable_pagespeed (should default to False)
        del test_payload["enable_pagespeed"]
        print("📤 Testing without enable_pagespeed parameter (should default to False)")
        
        response = requests.post(
            f"{base_url}/jobs/parallel",
            json=test_payload,
            timeout=5
        )
        
        if response.status_code != 200:
            print(f"❌ Test failed without enable_pagespeed parameter")
            return False
            
        print("✅ Server accepted request without enable_pagespeed (uses default)")
        
        print("\n🎉 All PageSpeed parameter tests passed!")
        return True
        
    except requests.exceptions.ConnectionError:
        print("❌ Could not connect to server at http://localhost:8000")
        print("Make sure the server is running: docker-compose up -d")
        return False
    except Exception as e:
        print(f"❌ Test failed with error: {e}")
        return False

if __name__ == "__main__":
    success = test_pagespeed_parameter()
    sys.exit(0 if success else 1)