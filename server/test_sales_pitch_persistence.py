#!/usr/bin/env python3
"""
Integration test for sales pitch persistence and data integrity.
Tests all aspects of the sales pitch A/B testing system.
"""

import requests
import json
import time
from datetime import datetime
from typing import Dict, Any, List

BASE_URL = "http://localhost:8000"

def test_sales_pitch_persistence():
    """Comprehensive test for sales pitch data persistence."""
    
    print("=" * 60)
    print("SALES PITCH PERSISTENCE INTEGRATION TEST")
    print("=" * 60)
    
    # Step 1: Create test sales pitches
    print("\n1. Creating test sales pitches...")
    pitch_a_data = {
        "name": "Test Pitch A - Control",
        "content": "Hello [Business Name], we help businesses in [Location] improve their online presence...",
        "is_active": True
    }
    pitch_b_data = {
        "name": "Test Pitch B - Variant",
        "content": "Hi [Business Name], did you know that 70% of customers in [Location] search online first?",
        "is_active": True
    }
    
    # Create pitches
    response_a = requests.post(f"{BASE_URL}/sales-pitches", json=pitch_a_data)
    assert response_a.status_code == 200, f"Failed to create pitch A: {response_a.text}"
    pitch_a = response_a.json()
    print(f"  ✓ Created Pitch A: {pitch_a['id']}")
    
    response_b = requests.post(f"{BASE_URL}/sales-pitches", json=pitch_b_data)
    assert response_b.status_code == 200, f"Failed to create pitch B: {response_b.text}"
    pitch_b = response_b.json()
    print(f"  ✓ Created Pitch B: {pitch_b['id']}")
    
    # Step 2: Create test lead
    print("\n2. Creating test lead...")
    lead_data = {
        "business_name": f"Test Business {datetime.now().strftime('%H%M%S')}",
        "phone": f"555-{datetime.now().strftime('%H%M')}",
        "location": "Test City, TS",
        "industry": "Test Industry",
        "has_website": False,
        "is_candidate": True,
        "status": "NEW"
    }
    
    response = requests.post(f"{BASE_URL}/leads", json=lead_data)
    assert response.status_code == 200, f"Failed to create lead: {response.text}"
    lead = response.json()
    lead_id = lead["id"]
    print(f"  ✓ Created Lead: {lead_id}")
    
    try:
        # Step 3: Assign pitch to lead
        print("\n3. Assigning pitch to lead...")
        assign_data = {"sales_pitch_id": pitch_a["id"]}
        response = requests.post(f"{BASE_URL}/leads/{lead_id}/assign-pitch", json=assign_data)
        assert response.status_code == 200, f"Failed to assign pitch: {response.text}"
        print(f"  ✓ Assigned Pitch A to lead")
        
        # Step 4: Verify pitch assignment persisted
        print("\n4. Verifying pitch assignment...")
        response = requests.get(f"{BASE_URL}/leads/{lead_id}")
        assert response.status_code == 200
        lead_data = response.json()
        assert lead_data["sales_pitch_id"] == pitch_a["id"], "Pitch ID not persisted"
        assert lead_data["sales_pitch"]["name"] == pitch_a_data["name"], "Pitch data not loaded"
        print(f"  ✓ Pitch assignment persisted correctly")
        
        # Step 5: Update lead status to CALLED
        print("\n5. Updating lead status to CALLED...")
        update_data = {
            "status": "CALLED",
            "sales_pitch_id": pitch_a["id"]
        }
        response = requests.put(f"{BASE_URL}/leads/{lead_id}", json=update_data)
        assert response.status_code == 200
        print(f"  ✓ Lead status updated to CALLED")
        
        # Step 6: Create call log with outcome (simplified data)
        print("\n6. Creating call log with outcome...")
        call_log_data = {
            "lead_id": lead_id,
            "sales_pitch_id": pitch_a["id"],
            "duration": 245,  # 4 minutes 5 seconds
            "outcome": "INTERESTED",
            "notes": "Prospect was interested, scheduled follow-up",
            "pitch_delivered_successfully": True,
            "pitch_resonated": True,
            "scheduled_follow_up": True,
            "follow_up_date": "2024-01-15T14:00:00"
        }
        response = requests.post(f"{BASE_URL}/call-logs", json=call_log_data)
        assert response.status_code == 200, f"Failed to create call log: {response.text}"
        call_log = response.json()
        print(f"  ✓ Created call log with outcome: {call_log['outcome']}")
        
        # Step 7: Verify pitch metrics updated
        print("\n7. Verifying pitch metrics updated...")
        response = requests.get(f"{BASE_URL}/sales-pitches/{pitch_a['id']}")
        assert response.status_code == 200
        updated_pitch = response.json()
        assert updated_pitch["attempts"] == 1, f"Expected 1 attempt, got {updated_pitch['attempts']}"
        assert updated_pitch["conversions"] == 1, f"Expected 1 conversion, got {updated_pitch['conversions']}"
        assert updated_pitch["conversion_rate"] == 100.0, f"Expected 100% rate, got {updated_pitch['conversion_rate']}"
        print(f"  ✓ Pitch metrics updated: {updated_pitch['attempts']} attempts, {updated_pitch['conversions']} conversions")
        
        # Step 8: Test pitch switching
        print("\n8. Testing pitch switching...")
        switch_data = {"sales_pitch_id": pitch_b["id"]}
        response = requests.post(f"{BASE_URL}/leads/{lead_id}/assign-pitch", json=switch_data)
        assert response.status_code == 200
        
        response = requests.get(f"{BASE_URL}/leads/{lead_id}")
        assert response.status_code == 200
        lead_data = response.json()
        assert lead_data["sales_pitch_id"] == pitch_b["id"], "Pitch switch not persisted"
        print(f"  ✓ Successfully switched from Pitch A to Pitch B")
        
        # Step 9: Test multiple calls with different outcomes
        print("\n9. Testing multiple call outcomes...")
        
        # Create another test lead for Pitch B
        lead2_data = {
            "business_name": f"Test Business 2 {datetime.now().strftime('%H%M%S')}",
            "phone": f"555-{datetime.now().strftime('%S%M')}",
            "location": "Test City, TS",
            "industry": "Test Industry",
            "has_website": True,
            "status": "NEW"
        }
        response = requests.post(f"{BASE_URL}/leads", json=lead2_data)
        assert response.status_code == 200
        lead2 = response.json()
        lead2_id = lead2["id"]
        
        # Assign Pitch B and make unsuccessful call (simplified data)
        requests.post(f"{BASE_URL}/leads/{lead2_id}/assign-pitch", json={"sales_pitch_id": pitch_b["id"]})
        call_log2_data = {
            "lead_id": lead2_id,
            "sales_pitch_id": pitch_b["id"],
            "duration": 60,
            "outcome": "NOT_INTERESTED",
            "notes": "Not interested at this time",
            "pitch_delivered_successfully": True,
            "pitch_resonated": False,
            "scheduled_follow_up": False
        }
        response = requests.post(f"{BASE_URL}/call-logs", json=call_log2_data)
        assert response.status_code == 200
        
        # Verify Pitch B metrics
        response = requests.get(f"{BASE_URL}/sales-pitches/{pitch_b['id']}")
        pitch_b_updated = response.json()
        assert pitch_b_updated["attempts"] == 1
        assert pitch_b_updated["conversions"] == 0
        assert pitch_b_updated["conversion_rate"] == 0.0
        print(f"  ✓ Pitch B metrics: {pitch_b_updated['attempts']} attempts, {pitch_b_updated['conversions']} conversions")
        
        # Step 10: Test data persistence after retrieval
        print("\n10. Testing data persistence after multiple retrievals...")
        for i in range(3):
            response = requests.get(f"{BASE_URL}/leads/{lead_id}")
            assert response.status_code == 200
            data = response.json()
            assert data["sales_pitch_id"] == pitch_b["id"], f"Pitch ID changed on retrieval {i+1}"
            assert "sales_pitch" in data, f"Pitch data missing on retrieval {i+1}"
        print(f"  ✓ Data remains consistent after multiple retrievals")
        
        # Step 11: Test timeline persistence
        print("\n11. Testing timeline entry persistence...")
        timeline_entry = {
            "type": "NOTE",
            "title": "Pitch effectiveness note",
            "description": f"Used {pitch_b['name']} - customer responded well to statistics",
            "metadata": {
                "sales_pitch_id": pitch_b["id"],
                "effectiveness": "high"
            }
        }
        response = requests.post(f"{BASE_URL}/leads/{lead_id}/timeline", json=timeline_entry)
        assert response.status_code == 200
        
        # Verify timeline entry persisted
        response = requests.get(f"{BASE_URL}/leads/{lead_id}/timeline")
        assert response.status_code == 200
        timeline = response.json()
        found_entry = False
        for entry in timeline:
            if entry.get("title") == "Pitch effectiveness note":
                found_entry = True
                assert entry["metadata"]["sales_pitch_id"] == pitch_b["id"]
                break
        assert found_entry, "Timeline entry not found"
        print(f"  ✓ Timeline entry with pitch metadata persisted")
        
        # Cleanup test leads
        print("\n12. Cleaning up test data...")
        requests.delete(f"{BASE_URL}/leads/{lead_id}")
        requests.delete(f"{BASE_URL}/leads/{lead2_id}")
        print(f"  ✓ Test leads deleted")
        
    except Exception as e:
        # Cleanup on failure
        print(f"\n✗ Test failed: {e}")
        try:
            requests.delete(f"{BASE_URL}/leads/{lead_id}")
            if 'lead2_id' in locals():
                requests.delete(f"{BASE_URL}/leads/{lead2_id}")
        except:
            pass
        raise
    
    finally:
        # Always cleanup pitches
        try:
            requests.delete(f"{BASE_URL}/sales-pitches/{pitch_a['id']}")
            requests.delete(f"{BASE_URL}/sales-pitches/{pitch_b['id']}")
            print(f"  ✓ Test pitches deleted")
        except:
            pass
    
    print("\n" + "=" * 60)
    print("✓ ALL PERSISTENCE TESTS PASSED")
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
    
    test_sales_pitch_persistence()