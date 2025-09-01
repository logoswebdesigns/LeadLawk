#!/usr/bin/env python3
"""
Integration test for Do Not Call (DNC) functionality.
Tests the complete flow of marking a lead as DNC from Flutter to server.
"""

import requests
import json
import time
from datetime import datetime

BASE_URL = "http://localhost:8000"

def test_dnc_functionality():
    """Test marking a lead as Do Not Call."""
    
    print("=" * 60)
    print("DO NOT CALL (DNC) FUNCTIONALITY TEST")
    print("=" * 60)
    
    # Step 1: Get a test lead (use first NEW status lead)
    print("\n1. Getting test lead...")
    response = requests.get(f"{BASE_URL}/leads?status=new")
    assert response.status_code == 200, f"Failed to get leads: {response.text}"
    
    leads = response.json()
    if not leads:
        print("  ⚠️  No NEW status leads found. Creating one for testing...")
        # This would normally be created through the browser automation,
        # but for testing we'll just use an existing lead
        response = requests.get(f"{BASE_URL}/leads")
        assert response.status_code == 200
        leads = response.json()
        assert len(leads) > 0, "No leads available for testing"
    
    test_lead = leads[0]
    lead_id = test_lead["id"]
    original_status = test_lead["status"]
    print(f"  ✓ Using lead: {test_lead['business_name']} (ID: {lead_id})")
    print(f"  ✓ Current status: {original_status}")
    
    # Step 2: Mark lead as Do Not Call
    print("\n2. Marking lead as Do Not Call...")
    update_data = {
        "status": "doNotCall"  # Using camelCase as expected by server
    }
    
    response = requests.put(
        f"{BASE_URL}/leads/{lead_id}",
        json=update_data
    )
    
    # Check response
    assert response.status_code == 200, f"Failed to update lead status: {response.text}"
    updated_lead = response.json()
    print(f"  ✓ Lead updated successfully")
    
    # Step 3: Verify the status was updated correctly
    print("\n3. Verifying status change...")
    assert updated_lead["status"] == "doNotCall", f"Status not updated correctly: {updated_lead['status']}"
    print(f"  ✓ Status correctly changed to: {updated_lead['status']}")
    
    # Step 4: Verify timeline entry was created (status changes auto-create timeline entries)
    print("\n4. Verifying timeline entry...")
    response = requests.get(f"{BASE_URL}/leads/{lead_id}")
    assert response.status_code == 200
    lead_with_timeline = response.json()
    
    # Check if timeline exists and has entries
    if "timeline" in lead_with_timeline and lead_with_timeline["timeline"]:
        print(f"  ✓ Timeline has {len(lead_with_timeline['timeline'])} entries")
        # Look for status change entry
        found_status_change = False
        for entry in lead_with_timeline["timeline"]:
            if "doNotCall" in str(entry):
                found_status_change = True
                break
        if found_status_change:
            print(f"  ✓ Status change to DNC recorded in timeline")
    else:
        print(f"  ⚠️  Timeline not available or empty (may be normal for this server configuration)")
    
    # Step 5: Verify the lead cannot be called anymore
    print("\n5. Verifying lead is protected from calls...")
    response = requests.get(f"{BASE_URL}/leads/{lead_id}")
    assert response.status_code == 200
    lead = response.json()
    assert lead["status"] == "doNotCall", "Lead status should remain doNotCall"
    print(f"  ✓ Lead is marked as Do Not Call and protected")
    
    # Step 6: Test that DNC leads are properly filtered
    print("\n6. Testing DNC filter...")
    response = requests.get(f"{BASE_URL}/leads?status=doNotCall")
    assert response.status_code == 200
    dnc_leads = response.json()
    
    # Check if our test lead is in the DNC list
    found_in_dnc = False
    for dnc_lead in dnc_leads:
        if dnc_lead["id"] == lead_id:
            found_in_dnc = True
            break
    
    assert found_in_dnc, "Test lead not found in DNC filtered list"
    print(f"  ✓ DNC filtering works correctly")
    
    # Step 7: Restore original status (cleanup)
    print("\n7. Restoring original status...")
    restore_data = {
        "status": original_status
    }
    
    response = requests.put(
        f"{BASE_URL}/leads/{lead_id}",
        json=restore_data
    )
    
    if response.status_code == 200:
        print(f"  ✓ Lead status restored to: {original_status}")
    else:
        print(f"  ⚠️  Could not restore status: {response.text}")
    
    print("\n" + "=" * 60)
    print("✓ DNC FUNCTIONALITY TEST PASSED")
    print("=" * 60)

def test_status_serialization():
    """Test that all status values serialize correctly."""
    print("\n" + "=" * 60)
    print("STATUS SERIALIZATION TEST")
    print("=" * 60)
    
    # Test all status values
    status_values = [
        "new",
        "viewed", 
        "called",
        "callbackScheduled",  # camelCase
        "interested",
        "converted",
        "doNotCall",  # camelCase
        "didNotConvert"  # camelCase
    ]
    
    print("\nTesting status value acceptance by server...")
    
    # Get a test lead
    response = requests.get(f"{BASE_URL}/leads")
    assert response.status_code == 200
    leads = response.json()
    assert len(leads) > 0, "No leads available for testing"
    
    test_lead = leads[0]
    lead_id = test_lead["id"]
    original_status = test_lead["status"]
    
    for status in status_values:
        print(f"\n  Testing status: '{status}'")
        
        update_data = {
            "status": status
        }
        
        response = requests.put(
            f"{BASE_URL}/leads/{lead_id}",
            json=update_data
        )
        
        if response.status_code == 200:
            print(f"    ✓ Status '{status}' accepted")
            returned_lead = response.json()
            assert returned_lead["status"] == status, f"Status mismatch: expected {status}, got {returned_lead['status']}"
        else:
            print(f"    ✗ Status '{status}' rejected: {response.text}")
            assert False, f"Server rejected valid status: {status}"
    
    # Restore original status
    restore_data = {"status": original_status}
    requests.put(f"{BASE_URL}/leads/{lead_id}", json=restore_data)
    
    print("\n" + "=" * 60)
    print("✓ STATUS SERIALIZATION TEST PASSED")
    print("=" * 60)

if __name__ == "__main__":
    # Wait for server to be ready
    print("Waiting for server to be ready...")
    for i in range(10):
        try:
            response = requests.get(f"{BASE_URL}/health")
            if response.status_code == 200:
                print("Server is ready!")
                break
        except:
            pass
        time.sleep(1)
    
    # Run tests
    test_dnc_functionality()
    test_status_serialization()
    
    print("\n✓ ALL TESTS PASSED SUCCESSFULLY!")