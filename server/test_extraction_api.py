#!/usr/bin/env python3
"""
API-based test for all 4 business listing scenarios.
Tests via the actual API endpoints to ensure end-to-end functionality.
"""

import requests
import json
import time
from typing import Dict, List

class ExtractionAPITester:
    """Test extraction via API calls"""
    
    def __init__(self, base_url="http://localhost:8000"):
        self.base_url = base_url
        self.results = {
            "standard_listings": [],
            "compact_listings": []
        }
        
    def start_search(self, query: str, limit: int = 10) -> str:
        """Start a search job and return job_id"""
        url = f"{self.base_url}/api/browser/start"
        
        payload = {
            "query": query,
            "limit": limit,
            "min_rating": 0,
            "min_reviews": 0,
            "requires_website": None,  # Get all businesses
            "enable_click_through": True,  # Enable to test compact listings
            "enable_pagespeed": False
        }
        
        print(f"🔍 Starting search: {query}")
        
        try:
            response = requests.post(url, json=payload)
            response.raise_for_status()
            data = response.json()
            job_id = data.get("job_id")
            print(f"✅ Job started: {job_id}")
            return job_id
        except Exception as e:
            print(f"❌ Failed to start search: {e}")
            return None
            
    def wait_for_completion(self, job_id: str, max_wait: int = 300) -> bool:
        """Wait for job to complete"""
        status_url = f"{self.base_url}/api/browser/status/{job_id}"
        start_time = time.time()
        
        while time.time() - start_time < max_wait:
            try:
                response = requests.get(status_url)
                if response.status_code == 200:
                    data = response.json()
                    status = data.get("status")
                    
                    if status == "completed":
                        print(f"✅ Job completed successfully")
                        return True
                    elif status in ["failed", "cancelled"]:
                        print(f"❌ Job {status}")
                        return False
                        
            except Exception as e:
                print(f"⚠️ Error checking status: {e}")
                
            time.sleep(5)
            
        print(f"⏱️ Job timed out after {max_wait} seconds")
        return False
        
    def get_results(self, job_id: str) -> List[Dict]:
        """Get search results for a job"""
        url = f"{self.base_url}/api/leads?job_id={job_id}"
        
        try:
            response = requests.get(url)
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"❌ Failed to get results: {e}")
            return []
            
    def analyze_results(self, results: List[Dict], search_type: str):
        """Analyze and categorize search results"""
        print(f"\n📊 Analyzing {len(results)} results from {search_type} search:")
        
        with_website = 0
        without_website = 0
        examples_with = []
        examples_without = []
        
        for lead in results:
            name = lead.get("business_name", "Unknown")
            has_website = lead.get("website_url") is not None
            
            if has_website:
                with_website += 1
                if len(examples_with) < 3:
                    examples_with.append({
                        "name": name,
                        "website": lead.get("website_url")
                    })
            else:
                without_website += 1
                if len(examples_without) < 3:
                    examples_without.append({"name": name})
                    
        # Store results
        self.results[f"{search_type}_listings"].extend(results)
        
        # Print analysis
        print(f"  ✅ With website: {with_website}")
        print(f"  ❌ Without website: {without_website}")
        
        if examples_with:
            print(f"\n  Examples with website:")
            for ex in examples_with:
                print(f"    • {ex['name'][:40]}")
                print(f"      {ex['website'][:60]}")
                
        if examples_without:
            print(f"\n  Examples without website:")
            for ex in examples_without:
                print(f"    • {ex['name'][:40]}")
                
        return with_website, without_website
        
    def test_standard_listings(self):
        """Test standard listings (painters)"""
        print("\n" + "="*60)
        print("📋 TESTING STANDARD LISTINGS")
        print("Expected: painter papillion (standard format)")
        print("="*60)
        
        job_id = self.start_search("painter papillion", limit=10)
        if not job_id:
            return False
            
        if self.wait_for_completion(job_id):
            results = self.get_results(job_id)
            with_site, without_site = self.analyze_results(results, "standard")
            
            if with_site > 0 and without_site > 0:
                print("✅ Found both types in standard listings")
                return True
            elif with_site > 0:
                print("⚠️ Only found standard listings with websites")
                return True  # Still acceptable
            else:
                print("❌ No variety in standard listings")
                return False
        return False
        
    def test_compact_listings(self):
        """Test compact listings (dentists)"""
        print("\n" + "="*60)
        print("📦 TESTING COMPACT LISTINGS")
        print("Expected: dentist papillion (compact format)")
        print("="*60)
        
        job_id = self.start_search("dentist papillion", limit=10)
        if not job_id:
            return False
            
        if self.wait_for_completion(job_id):
            results = self.get_results(job_id)
            with_site, without_site = self.analyze_results(results, "compact")
            
            if with_site > 0:
                print("✅ Compact listing website extraction is working!")
                return True
            else:
                print("❌ No websites found in compact listings - extraction may be broken")
                return False
        return False
        
    def run_all_tests(self):
        """Run all tests and print summary"""
        print("\n🚀 Business Listing Extraction Test Suite")
        print("Testing all 4 scenarios via API")
        
        standard_pass = self.test_standard_listings()
        compact_pass = self.test_compact_listings()
        
        # Print summary
        print("\n" + "="*60)
        print("📈 TEST SUMMARY")
        print("="*60)
        
        total_businesses = len(self.results["standard_listings"]) + len(self.results["compact_listings"])
        print(f"\nTotal businesses tested: {total_businesses}")
        
        # Count scenarios found
        scenarios_found = []
        
        # Check standard listings
        standard_with = sum(1 for r in self.results["standard_listings"] if r.get("website_url"))
        standard_without = len(self.results["standard_listings"]) - standard_with
        
        # Check compact listings  
        compact_with = sum(1 for r in self.results["compact_listings"] if r.get("website_url"))
        compact_without = len(self.results["compact_listings"]) - compact_with
        
        print(f"\nScenarios detected:")
        if standard_with > 0:
            print(f"  ✅ Standard with website: {standard_with}")
            scenarios_found.append("standard_with_website")
        if standard_without > 0:
            print(f"  ✅ Standard without website: {standard_without}")
            scenarios_found.append("standard_without_website")
        if compact_with > 0:
            print(f"  ✅ Compact with website: {compact_with}")
            scenarios_found.append("compact_with_website")
        if compact_without > 0:
            print(f"  ✅ Compact without website: {compact_without}")
            scenarios_found.append("compact_without_website")
            
        # Final verdict
        print("\n" + "="*60)
        if len(scenarios_found) >= 3:  # At least 3 out of 4 scenarios
            print("✅ TEST PASSED: Extraction logic is working correctly!")
            print(f"   Detected {len(scenarios_found)}/4 listing scenarios")
            
            # Special check for compact with website (most important)
            if "compact_with_website" in scenarios_found:
                print("   ✅ Critical: Compact listing website extraction working!")
            return True
        else:
            print("❌ TEST FAILED: Extraction logic needs attention")
            print(f"   Only detected {len(scenarios_found)}/4 listing scenarios")
            
            if "compact_with_website" not in scenarios_found:
                print("   ❌ Critical: Compact listing website extraction NOT working!")
                print("   This is the main issue that needs fixing")
            return False
            
def main():
    """Run the test suite"""
    tester = ExtractionAPITester()
    
    success = tester.run_all_tests()
    
    # Save results
    with open("test_extraction_results.json", "w") as f:
        json.dump({
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
            "success": success,
            "standard_listings": len(tester.results["standard_listings"]),
            "compact_listings": len(tester.results["compact_listings"])
        }, f, indent=2)
        
    print(f"\n📁 Results saved to test_extraction_results.json")
    
    exit(0 if success else 1)
    
if __name__ == "__main__":
    main()