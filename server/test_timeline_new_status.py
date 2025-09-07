#!/usr/bin/env python3
"""
Test to ensure new_status is always populated for STATUS_CHANGE timeline entries.
This test verifies that the new_status field is never null when creating
STATUS_CHANGE timeline entries.
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from datetime import datetime
import uuid
from database import SessionLocal
from models import Lead, LeadTimelineEntry, LeadStatus, TimelineEntryType
from lead_management import update_lead
from schemas import LeadUpdate


def test_new_status_never_null():
    """Test that new_status is always populated for STATUS_CHANGE entries"""
    db = SessionLocal()
    test_results = []
    
    try:
        print("\n" + "="*60)
        print("🧪 Testing new_status Population for STATUS_CHANGE Entries")
        print("="*60)
        
        # Step 1: Create a test lead
        print("\n1️⃣ Creating test lead...")
        test_lead = Lead(
            id=f"test_lead_{uuid.uuid4().hex[:8]}",
            business_name="Test Business for Status Change",
            phone="555-0123",
            industry="Test Industry",  # Required field
            location="Test Location",  # Optional but good to have
            status=LeadStatus.new,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )
        db.add(test_lead)
        db.commit()
        print(f"   ✅ Created lead: {test_lead.id}")
        
        # Step 2: Test status changes through update_lead function
        print("\n2️⃣ Testing status changes through update_lead...")
        status_transitions = [
            (LeadStatus.new, LeadStatus.viewed),
            (LeadStatus.viewed, LeadStatus.called),
            (LeadStatus.called, LeadStatus.interested),
            (LeadStatus.interested, LeadStatus.converted)
        ]
        
        for old_status, new_status in status_transitions:
            print(f"\n   Testing: {old_status.value} → {new_status.value}")
            
            # Update the lead status
            update_data = LeadUpdate(status=new_status.value)
            updated_lead = update_lead(test_lead.id, update_data)
            
            if not updated_lead:
                test_results.append(("❌", f"Failed to update lead status to {new_status.value}"))
                continue
            
            # Check the timeline entry
            timeline_entry = db.query(LeadTimelineEntry).filter(
                LeadTimelineEntry.lead_id == test_lead.id,
                LeadTimelineEntry.type == TimelineEntryType.STATUS_CHANGE,
                LeadTimelineEntry.new_status == new_status
            ).order_by(LeadTimelineEntry.created_at.desc()).first()
            
            if not timeline_entry:
                test_results.append(("❌", f"No timeline entry found for status change to {new_status.value}"))
            elif timeline_entry.new_status is None:
                test_results.append(("❌", f"new_status is NULL for {new_status.value} change"))
            elif timeline_entry.new_status != new_status:
                test_results.append(("❌", f"new_status mismatch: expected {new_status.value}, got {timeline_entry.new_status.value}"))
            else:
                test_results.append(("✅", f"new_status correctly set to {new_status.value}"))
                print(f"      ✅ new_status = {timeline_entry.new_status.value}")
                print(f"      ✅ previous_status = {timeline_entry.previous_status.value if timeline_entry.previous_status else 'None'}")
        
        # Step 3: Test direct timeline entry creation (for completeness)
        print("\n3️⃣ Testing direct timeline entry creation...")
        direct_entry = LeadTimelineEntry(
            id=f"direct_test_{uuid.uuid4().hex[:8]}",
            lead_id=test_lead.id,
            type=TimelineEntryType.STATUS_CHANGE,
            title="Direct Status Change Test",
            description="Testing direct creation",
            previous_status=LeadStatus.converted,
            new_status=LeadStatus.doNotCall,
            created_at=datetime.utcnow()
        )
        db.add(direct_entry)
        db.commit()
        
        # Verify it was saved correctly
        saved_entry = db.query(LeadTimelineEntry).filter(
            LeadTimelineEntry.id == direct_entry.id
        ).first()
        
        if saved_entry and saved_entry.new_status == LeadStatus.doNotCall:
            test_results.append(("✅", "Direct creation with new_status works"))
            print(f"   ✅ Direct entry new_status = {saved_entry.new_status.value}")
        else:
            test_results.append(("❌", "Direct creation failed to save new_status"))
        
        # Step 4: Check for any NULL new_status entries
        print("\n4️⃣ Checking for NULL new_status in STATUS_CHANGE entries...")
        null_entries = db.query(LeadTimelineEntry).filter(
            LeadTimelineEntry.type == TimelineEntryType.STATUS_CHANGE,
            LeadTimelineEntry.new_status == None
        ).all()
        
        if null_entries:
            test_results.append(("❌", f"Found {len(null_entries)} entries with NULL new_status"))
            print(f"   ❌ Found {len(null_entries)} STATUS_CHANGE entries with NULL new_status")
            for entry in null_entries[:5]:  # Show first 5
                print(f"      - ID: {entry.id}, Lead: {entry.lead_id}, Title: {entry.title}")
        else:
            test_results.append(("✅", "No STATUS_CHANGE entries with NULL new_status"))
            print(f"   ✅ No STATUS_CHANGE entries have NULL new_status")
        
        # Clean up test data
        print("\n5️⃣ Cleaning up test data...")
        db.query(LeadTimelineEntry).filter(
            LeadTimelineEntry.lead_id == test_lead.id
        ).delete()
        db.query(Lead).filter(Lead.id == test_lead.id).delete()
        db.commit()
        print("   ✅ Test data cleaned up")
        
    except Exception as e:
        print(f"\n❌ Test failed with error: {e}")
        test_results.append(("❌", f"Test error: {str(e)}"))
        db.rollback()
    finally:
        db.close()
    
    # Print summary
    print("\n" + "="*60)
    print("📊 Test Summary")
    print("="*60)
    
    passed = sum(1 for status, _ in test_results if status == "✅")
    failed = sum(1 for status, _ in test_results if status == "❌")
    
    for status, message in test_results:
        print(f"{status} {message}")
    
    print("\n" + "-"*60)
    print(f"Total: {len(test_results)} tests")
    print(f"Passed: {passed} ✅")
    print(f"Failed: {failed} ❌")
    
    if failed == 0:
        print("\n🎉 All tests passed! new_status is properly populated.")
        return True
    else:
        print(f"\n⚠️ {failed} test(s) failed. Review the implementation.")
        return False


if __name__ == "__main__":
    success = test_new_status_never_null()
    sys.exit(0 if success else 1)