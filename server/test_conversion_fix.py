#!/usr/bin/env python3
"""Test and fix conversion scoring endpoint."""

import requests
import traceback

BASE_URL = "http://localhost:8000"

def test_conversion_endpoint():
    """Test the conversion scoring endpoint and get detailed error."""
    print("Testing conversion scoring endpoint...")
    
    try:
        response = requests.post(f"{BASE_URL}/conversion/calculate")
        print(f"Status Code: {response.status_code}")
        
        if response.status_code == 500:
            print("Error Response:")
            print(response.text)
            
            # Try to parse error details
            try:
                error_data = response.json()
                print("\nError details:", error_data)
            except:
                pass
                
        elif response.status_code == 200:
            print("Success!")
            print(response.json())
    except Exception as e:
        print(f"Request failed: {e}")
        traceback.print_exc()

if __name__ == "__main__":
    test_conversion_endpoint()