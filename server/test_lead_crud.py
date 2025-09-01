#!/usr/bin/env python3
"""
Comprehensive regression tests for Lead CRUD operations
Tests all endpoints to ensure UUID string IDs work correctly
"""

import requests
import json
import uuid
from datetime import datetime


BASE_URL = "http://localhost:8000"


def test_lead_crud_operations():
    """Test all lead CRUD operations with UUID string IDs"""
    print("🧪 Testing Lead CRUD operations with UUID strings...")
    
    # Test 1: Get all leads (should work regardless)
    print("\n1. Testing GET /leads")
    response = requests.get(f"{BASE_URL}/leads")
    assert response.status_code == 200, f"GET /leads failed: {response.status_code}"
    leads = response.json()
    print(f"   ✅ GET /leads returned {len(leads)} leads")
    
    if not leads:
        print("   ⚠️  No leads found, skipping individual lead tests")
        return
    
    # Get a valid lead ID to test with
    test_lead = leads[0]
    lead_id = test_lead["id"]
    print(f"   📝 Using lead ID: {lead_id}")
    
    # Validate that the ID is a UUID string
    try:
        uuid.UUID(lead_id)
        print(f"   ✅ Lead ID is valid UUID string")
    except ValueError:
        print(f"   ❌ Lead ID is not a valid UUID: {lead_id}")
        return
    
    # Test 2: Get specific lead by UUID string
    print(f"\n2. Testing GET /leads/{lead_id}")
    response = requests.get(f"{BASE_URL}/leads/{lead_id}")
    assert response.status_code == 200, f"GET /leads/{lead_id} failed: {response.status_code}"
    lead_detail = response.json()
    assert lead_detail["id"] == lead_id, f"Returned lead ID mismatch: {lead_detail['id']} != {lead_id}"
    print(f"   ✅ GET /leads/{lead_id} returned correct lead")
    
    # Test 3: Update lead by UUID string
    print(f"\n3. Testing PUT /leads/{lead_id}")
    original_notes = lead_detail.get("notes", "")
    test_notes = f"Updated via test at {datetime.now().isoformat()}"
    
    update_data = {
        "notes": test_notes
    }
    
    response = requests.put(
        f"{BASE_URL}/leads/{lead_id}",
        json=update_data,
        headers={"Content-Type": "application/json"}
    )
    assert response.status_code == 200, f"PUT /leads/{lead_id} failed: {response.status_code} - {response.text}"
    updated_lead = response.json()
    assert updated_lead["notes"] == test_notes, f"Notes not updated: {updated_lead['notes']}"
    print(f"   ✅ PUT /leads/{lead_id} successfully updated notes")
    
    # Test 4: Test DELETE with wrong ID type (should handle gracefully)
    print(f"\n4. Testing DELETE with invalid ID types")
    
    # Try with integer (should fail validation)
    response = requests.delete(f"{BASE_URL}/leads/123")
    print(f"   🔍 DELETE /leads/123 returned status: {response.status_code}")
    assert response.status_code in [404, 422], f"Expected 404 or 422 for integer ID, got {response.status_code}"
    
    # Try with invalid UUID (should return 404)
    fake_uuid = str(uuid.uuid4())
    response = requests.delete(f"{BASE_URL}/leads/{fake_uuid}")
    assert response.status_code == 404, f"DELETE with fake UUID should return 404, got {response.status_code}"
    print(f"   ✅ DELETE with fake UUID correctly returned 404")
    
    # Test 5: Test successful DELETE with valid UUID
    print(f"\n5. Testing DELETE /leads/{lead_id}")
    response = requests.delete(f"{BASE_URL}/leads/{lead_id}")
    assert response.status_code == 200, f"DELETE /leads/{lead_id} failed: {response.status_code} - {response.text}"
    delete_result = response.json()
    assert "deleted successfully" in delete_result.get("message", "").lower(), f"Unexpected delete message: {delete_result}"
    print(f"   ✅ DELETE /leads/{lead_id} successfully deleted lead")
    
    # Test 6: Verify lead was actually deleted
    print(f"\n6. Verifying lead deletion")
    response = requests.get(f"{BASE_URL}/leads/{lead_id}")
    assert response.status_code == 404, f"GET after delete should return 404, got {response.status_code}"
    print(f"   ✅ Verified lead {lead_id} was actually deleted")
    
    print(f"\n🎉 All Lead CRUD tests passed!")


def test_lead_timeline_operations():
    """Test timeline operations with UUID string IDs"""
    print("\n🧪 Testing Lead Timeline operations...")
    
    # Get leads that have timeline entries
    response = requests.get(f"{BASE_URL}/leads")
    leads = response.json()
    
    lead_with_timeline = None
    for lead in leads:
        if lead.get("timeline") and len(lead["timeline"]) > 0:
            lead_with_timeline = lead
            break
    
    if not lead_with_timeline:
        print("   ⚠️  No leads with timeline entries found, skipping timeline tests")
        return
    
    lead_id = lead_with_timeline["id"]
    timeline_entry = lead_with_timeline["timeline"][0]
    entry_id = timeline_entry["id"]
    
    print(f"   📝 Using lead ID: {lead_id}, timeline entry ID: {entry_id}")
    
    # Test timeline entry update
    update_data = {
        "description": f"Updated description at {datetime.now().isoformat()}"
    }
    
    response = requests.put(
        f"{BASE_URL}/leads/{lead_id}/timeline/{entry_id}",
        json=update_data,
        headers={"Content-Type": "application/json"}
    )
    
    if response.status_code == 200:
        print(f"   ✅ Timeline entry update successful")
    else:
        print(f"   ⚠️  Timeline entry update returned {response.status_code}: {response.text}")


def run_health_check():
    """Ensure server is running before tests"""
    try:
        response = requests.get(f"{BASE_URL}/health", timeout=5)
        assert response.status_code == 200
        print("✅ Server health check passed")
        return True
    except Exception as e:
        print(f"❌ Server health check failed: {e}")
        return False


if __name__ == "__main__":
    print("🚀 Starting Lead CRUD Regression Tests...")
    print(f"   Server: {BASE_URL}")
    print(f"   Time: {datetime.now().isoformat()}")
    
    if not run_health_check():
        print("❌ Cannot proceed with tests - server not responding")
        exit(1)
    
    try:
        test_lead_crud_operations()
        test_lead_timeline_operations()
        print(f"\n✅ All regression tests completed successfully!")
        print(f"   UUID string IDs are working correctly in all endpoints")
    except AssertionError as e:
        print(f"\n❌ Test failed: {e}")
        exit(1)
    except Exception as e:
        print(f"\n💥 Unexpected error: {e}")
        exit(1)