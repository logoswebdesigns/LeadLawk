#!/usr/bin/env python3
"""
Test script to verify Google Places API integration
Run this after adding your Google API key to .env
"""

import asyncio
import httpx
import json
import os
from dotenv import load_dotenv

load_dotenv()

async def test_google_api():
    """Test the maps proxy with Google API"""
    
    # Check if Google API key is set
    api_key = os.getenv("GOOGLE_MAPS_API_KEY")
    if not api_key or api_key == "your_google_api_key_here":
        print("❌ Google API key not configured in .env")
        print("   Add your key: GOOGLE_MAPS_API_KEY=your_actual_key")
        return
    
    print(f"✅ Google API key found: {api_key[:10]}...")
    
    # Test the proxy
    async with httpx.AsyncClient() as client:
        # Test 1: Search for businesses
        print("\n📍 Testing business search...")
        response = await client.post(
            "http://localhost:8001/search/places",
            json={
                "query": "restaurants in Austin, TX",
                "limit": 3,
                "provider": "google"  # Force Google provider
            }
        )
        
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Found {data['total']} places using {data['provider']}")
            
            for place in data['places']:
                print(f"\n🏢 {place['name']}")
                print(f"   📍 {place['address']}")
                print(f"   ⭐ Rating: {place.get('rating', 'N/A')} ({place.get('review_count', 0)} reviews)")
                print(f"   📞 Phone: {place.get('phone', 'N/A')}")
                print(f"   🌐 Website: {place.get('website', 'N/A')}")
                if place.get('hours'):
                    print(f"   🕐 Hours: Available")
        else:
            print(f"❌ Error: {response.status_code}")
            print(response.text)
    
    print("\n" + "="*50)
    print("When you add your Google API key, you'll get:")
    print("✅ Business names and addresses")
    print("✅ Phone numbers (95%+ availability)")
    print("✅ Websites (80%+ availability)")
    print("✅ Ratings and review counts")
    print("✅ Opening hours")
    print("✅ Photos")
    print("✅ Direct Google Maps URLs")

if __name__ == "__main__":
    asyncio.run(test_google_api())