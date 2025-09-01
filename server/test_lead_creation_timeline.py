#!/usr/bin/env python3
"""
Test to verify that lead creation process creates a timeline entry
"""

import unittest
import uuid
from datetime import datetime
from database import SessionLocal, engine
from models import Lead, LeadStatus, LeadTimelineEntry, TimelineEntryType
from database_operations import save_lead_to_database

class TestLeadCreationTimeline(unittest.TestCase):
    """Test that lead creation properly creates timeline entries"""
    
    def setUp(self):
        """Set up test database session"""
        self.db = SessionLocal()
        
    def tearDown(self):
        """Clean up test data"""
        # Clean up any test leads created
        if hasattr(self, 'test_lead_id'):
            # Delete timeline entries first
            self.db.query(LeadTimelineEntry).filter(
                LeadTimelineEntry.lead_id == self.test_lead_id
            ).delete()
            # Then delete the lead
            self.db.query(Lead).filter(Lead.id == self.test_lead_id).delete()
            self.db.commit()
        self.db.close()
        
    def test_lead_creation_creates_timeline_entry(self):
        """Test that creating a lead automatically creates a LEAD_CREATED timeline entry"""
        
        # Prepare test business details
        business_details = {
            'name': f'Test Business {uuid.uuid4().hex[:8]}',
            'industry': 'Test Industry',
            'rating': 4.5,
            'reviews': 100,
            'website': 'https://testbusiness.com',
            'has_website': True,
            'phone': '(555) 123-4567',
            'url': 'https://maps.google.com/test',
            'location': 'Test City',
            'has_recent_reviews': True,
            'screenshot_filename': None
        }
        
        # Create the lead using the standard function
        lead_id = save_lead_to_database(business_details, job_id='test-job-123')
        self.test_lead_id = lead_id  # Store for cleanup
        
        # Assert lead was created
        self.assertIsNotNone(lead_id, "Lead should be created successfully")
        
        # Verify the lead exists
        lead = self.db.query(Lead).filter(Lead.id == lead_id).first()
        self.assertIsNotNone(lead, "Lead should exist in database")
        self.assertEqual(lead.business_name, business_details['name'])
        self.assertEqual(lead.status, LeadStatus.NEW)
        
        # Verify timeline entry was created
        timeline_entries = self.db.query(LeadTimelineEntry).filter(
            LeadTimelineEntry.lead_id == lead_id
        ).all()
        
        self.assertGreaterEqual(len(timeline_entries), 1, "At least one timeline entry should exist")
        
        # Find the LEAD_CREATED entry
        creation_entry = None
        for entry in timeline_entries:
            if entry.type == TimelineEntryType.LEAD_CREATED:
                creation_entry = entry
                break
                
        self.assertIsNotNone(creation_entry, "LEAD_CREATED timeline entry should exist")
        
        # Verify the creation entry details
        self.assertEqual(creation_entry.type, TimelineEntryType.LEAD_CREATED)
        self.assertEqual(creation_entry.title, "Lead Created")
        self.assertIn("Test Industry", creation_entry.description)
        self.assertIn("Test City", creation_entry.description)
        self.assertIn("Has website", creation_entry.description)
        
        # Verify the timestamp is recent (within last minute)
        time_diff = datetime.utcnow() - creation_entry.created_at
        self.assertLess(time_diff.total_seconds(), 60, "Creation entry should have recent timestamp")
        
        print(f"✅ Test passed: Lead creation properly creates timeline entry")
        print(f"  Lead ID: {lead_id}")
        print(f"  Business: {lead.business_name}")
        print(f"  Timeline Entry: {creation_entry.title}")
        print(f"  Description: {creation_entry.description}")
        
    def test_lead_without_website_timeline_entry(self):
        """Test that leads without websites get proper timeline description"""
        
        # Prepare test business details without website
        business_details = {
            'name': f'Test No Website Business {uuid.uuid4().hex[:8]}',
            'industry': 'Plumbing',
            'rating': 3.8,
            'reviews': 45,
            'website': None,
            'has_website': False,
            'phone': '(555) 987-6543',
            'url': 'https://maps.google.com/test2',
            'location': 'Test Town',
            'has_recent_reviews': True,
            'screenshot_filename': None
        }
        
        # Create the lead
        lead_id = save_lead_to_database(business_details, job_id='test-job-456')
        self.test_lead_id = lead_id  # Store for cleanup
        
        self.assertIsNotNone(lead_id, "Lead should be created successfully")
        
        # Get the creation timeline entry
        creation_entry = self.db.query(LeadTimelineEntry).filter(
            LeadTimelineEntry.lead_id == lead_id,
            LeadTimelineEntry.type == TimelineEntryType.LEAD_CREATED
        ).first()
        
        self.assertIsNotNone(creation_entry, "LEAD_CREATED timeline entry should exist")
        
        # Verify it mentions "No website (candidate)"
        self.assertIn("No website (candidate)", creation_entry.description)
        
        print(f"✅ Test passed: Lead without website has proper timeline description")
        print(f"  Description: {creation_entry.description}")

def run_migration_test():
    """Test the migration script"""
    print("\n🔄 Testing Migration Script")
    print("="*50)
    
    db = SessionLocal()
    
    try:
        # Create a test lead without timeline entry (simulate old lead)
        test_lead = Lead(
            id=str(uuid.uuid4()),
            business_name="Old Lead Without Timeline",
            industry="Test",
            rating=4.0,
            review_count=50,
            website_url=None,
            has_website=False,
            phone="(555) 000-0000",
            location="Old Town",
            status=LeadStatus.NEW,
            created_at=datetime(2024, 1, 1, 12, 0, 0)  # Old date
        )
        db.add(test_lead)
        db.commit()
        
        print(f"Created test lead without timeline: {test_lead.business_name}")
        
        # Run the migration
        from migrate_lead_creation_entries import add_missing_lead_created_entries, verify_migration
        add_missing_lead_created_entries()
        
        # Verify the migration worked
        timeline_entry = db.query(LeadTimelineEntry).filter(
            LeadTimelineEntry.lead_id == test_lead.id,
            LeadTimelineEntry.type == TimelineEntryType.LEAD_CREATED
        ).first()
        
        assert timeline_entry is not None, "Migration should create timeline entry"
        assert timeline_entry.created_at == test_lead.created_at, "Timeline entry should use lead's creation date"
        
        print(f"✅ Migration test passed: Timeline entry created with date {timeline_entry.created_at}")
        
        # Clean up
        db.query(LeadTimelineEntry).filter(LeadTimelineEntry.lead_id == test_lead.id).delete()
        db.query(Lead).filter(Lead.id == test_lead.id).delete()
        db.commit()
        
    except Exception as e:
        print(f"❌ Migration test failed: {str(e)}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    print("🧪 Lead Creation Timeline Test Suite")
    print("="*50)
    
    # Run unit tests
    unittest.main(argv=[''], exit=False, verbosity=2)
    
    # Run migration test
    run_migration_test()