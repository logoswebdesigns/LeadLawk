#!/usr/bin/env python3
"""
Server-side Unit Tests
Tests all critical server components to prevent runtime errors.
"""

import unittest
import sys
import os
import tempfile
import json
from datetime import datetime, timedelta
from unittest.mock import Mock, patch, MagicMock

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Import modules to test
from models import LeadStatus, TimelineEntryType, Lead, LeadTimelineEntry, ConversionModel
from database import Base, SessionLocal
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker


class TestEnumConsistency(unittest.TestCase):
    """Test that all enum values are correctly defined and accessible."""
    
    def test_lead_status_values(self):
        """Test LeadStatus enum values."""
        # Test lowercase values (correct)
        self.assertEqual(LeadStatus.new.value, "new")
        self.assertEqual(LeadStatus.viewed.value, "viewed")
        self.assertEqual(LeadStatus.called.value, "called")
        self.assertEqual(LeadStatus.callbackScheduled.value, "callbackScheduled")
        self.assertEqual(LeadStatus.interested.value, "interested")
        self.assertEqual(LeadStatus.converted.value, "converted")
        self.assertEqual(LeadStatus.doNotCall.value, "doNotCall")
        self.assertEqual(LeadStatus.didNotConvert.value, "didNotConvert")
        
        # Test that uppercase attributes don't exist (should raise AttributeError)
        with self.assertRaises(AttributeError):
            _ = LeadStatus.CONVERTED
        with self.assertRaises(AttributeError):
            _ = LeadStatus.NEW
        with self.assertRaises(AttributeError):
            _ = LeadStatus.DNC
        with self.assertRaises(AttributeError):
            _ = LeadStatus.INTERESTED
        with self.assertRaises(AttributeError):
            _ = LeadStatus.CALLED
            
        print("✓ LeadStatus enum values are correctly defined (lowercase)")
        
    def test_timeline_entry_type_values(self):
        """Test TimelineEntryType enum values."""
        # These should be uppercase (correct)
        self.assertEqual(TimelineEntryType.LEAD_CREATED.value, "lead_created")
        self.assertEqual(TimelineEntryType.STATUS_CHANGE.value, "status_change")
        self.assertEqual(TimelineEntryType.NOTE.value, "note")
        self.assertEqual(TimelineEntryType.FOLLOW_UP.value, "follow_up")
        
        print("✓ TimelineEntryType enum values are correctly defined (uppercase)")


class TestConversionScoringService(unittest.TestCase):
    """Test conversion scoring service to prevent runtime errors."""
    
    def setUp(self):
        """Set up test database."""
        # Create in-memory SQLite database for testing
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(bind=self.engine)
        self.SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=self.engine)
        self.db = self.SessionLocal()
        
    def tearDown(self):
        """Clean up test database."""
        self.db.close()
        
    def test_conversion_scoring_imports(self):
        """Test that conversion scoring service can be imported without errors."""
        try:
            from conversion_scoring_service import ConversionScoringService
            print("✓ ConversionScoringService imports successfully")
        except ImportError as e:
            self.fail(f"Failed to import ConversionScoringService: {e}")
        except Exception as e:
            self.fail(f"Error importing ConversionScoringService: {e}")
            
    def test_conversion_scoring_initialization(self):
        """Test that conversion scoring service initializes correctly."""
        from conversion_scoring_service import ConversionScoringService
        
        service = ConversionScoringService(self.db)
        self.assertIsNotNone(service)
        self.assertEqual(service.db, self.db)
        print("✓ ConversionScoringService initializes correctly")
        
    def test_feature_extraction(self):
        """Test feature extraction doesn't crash with various lead states."""
        from conversion_scoring_service import ConversionScoringService
        
        service = ConversionScoringService(self.db)
        
        # Create test lead with minimal data
        lead = Lead(
            id="test-lead-1",
            business_name="Test Business",
            phone="555-1234",
            industry="plumbing",
            location="Test City",
            source="test",
            status=LeadStatus.new,  # Use correct lowercase
            has_website=False,
            meets_rating_threshold=False,
            has_recent_reviews=False,
            is_candidate=True,
            created_at=datetime.utcnow()
        )
        
        # Extract features shouldn't crash
        features = service._extract_features(lead)
        self.assertIsInstance(features, dict)
        self.assertIn('has_website', features)
        self.assertIn('rating_score', features)
        print("✓ Feature extraction works without errors")
        
    def test_score_calculation(self):
        """Test score calculation with various lead states."""
        from conversion_scoring_service import ConversionScoringService
        
        service = ConversionScoringService(self.db)
        
        # Create and save test lead
        lead = Lead(
            id="test-lead-2",
            business_name="Test Business 2",
            phone="555-5678",
            industry="hvac",
            location="Test City",
            source="test",
            status=LeadStatus.interested,  # Use correct lowercase
            has_website=True,
            meets_rating_threshold=True,
            has_recent_reviews=True,
            is_candidate=False,
            rating=4.5,
            review_count=50,
            created_at=datetime.utcnow()
        )
        
        self.db.add(lead)
        self.db.commit()
        
        # Calculate score
        score = service.calculate_score(lead.id)
        self.assertIsNotNone(score)
        self.assertGreaterEqual(score, 0.0)
        self.assertLessEqual(score, 1.0)
        print(f"✓ Score calculation works: {score:.2f}")
        
    def test_model_training_enum_usage(self):
        """Test that model training uses correct enum attributes."""
        from conversion_scoring_service import ConversionScoringService
        
        service = ConversionScoringService(self.db)
        
        # Add some test leads with different statuses
        statuses = [
            LeadStatus.new,
            LeadStatus.converted,  # Correct lowercase
            LeadStatus.interested,
            LeadStatus.doNotCall
        ]
        
        for i, status in enumerate(statuses):
            lead = Lead(
                id=f"test-lead-{i+10}",
                business_name=f"Test Business {i+10}",
                phone=f"555-{1000+i}",
                industry="construction",
                location="Test City",
                source="test",
                status=status,
                has_website=i % 2 == 0,
                meets_rating_threshold=i % 2 == 1,
                has_recent_reviews=True,
                is_candidate=True,
                created_at=datetime.utcnow()
            )
            self.db.add(lead)
        
        self.db.commit()
        
        # Training should not crash
        try:
            service.train_model()
            print("✓ Model training completes without enum errors")
        except AttributeError as e:
            if "CONVERTED" in str(e) or "DNC" in str(e):
                self.fail(f"Model training uses incorrect enum attribute: {e}")
            raise


class TestAnalyticsEngine(unittest.TestCase):
    """Test analytics engine for enum usage errors."""
    
    def setUp(self):
        """Set up test database."""
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(bind=self.engine)
        self.SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=self.engine)
        self.db = self.SessionLocal()
        
    def tearDown(self):
        """Clean up test database."""
        self.db.close()
        
    def test_analytics_imports(self):
        """Test that analytics engine can be imported."""
        try:
            from analytics_engine import AnalyticsEngine
            print("✓ AnalyticsEngine imports successfully")
        except ImportError as e:
            self.fail(f"Failed to import AnalyticsEngine: {e}")
            
    def test_analytics_enum_usage(self):
        """Test that analytics uses correct enum attributes."""
        from analytics_engine import AnalyticsEngine
        
        analytics = AnalyticsEngine(self.db)
        
        # Add test data
        for i in range(5):
            lead = Lead(
                id=f"analytics-lead-{i}",
                business_name=f"Analytics Test {i}",
                phone=f"555-{2000+i}",
                industry="plumbing",
                location="Test City",
                source="test",
                status=LeadStatus.converted if i < 2 else LeadStatus.new,  # Correct lowercase
                has_website=True,
                meets_rating_threshold=True,
                has_recent_reviews=True,
                is_candidate=False,
                created_at=datetime.utcnow()
            )
            self.db.add(lead)
        
        self.db.commit()
        
        # Get summary should not crash
        try:
            summary = analytics.get_summary()
            self.assertIsInstance(summary, dict)
            print("✓ Analytics summary works without enum errors")
        except AttributeError as e:
            if "CONVERTED" in str(e) or "INTERESTED" in str(e) or "CALLED" in str(e):
                self.fail(f"Analytics uses incorrect enum attribute: {e}")
            raise


class TestDatabaseOperations(unittest.TestCase):
    """Test database operations and model consistency."""
    
    def setUp(self):
        """Set up test database."""
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(bind=self.engine)
        self.SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=self.engine)
        self.db = self.SessionLocal()
        
    def tearDown(self):
        """Clean up."""
        self.db.close()
        
    def test_lead_model_status_field(self):
        """Test that Lead model correctly stores status values."""
        # Create lead with each status
        for status in LeadStatus:
            lead = Lead(
                id=f"status-test-{status.value}",
                business_name=f"Status Test {status.value}",
                phone="555-0000",
                industry="test",
                location="Test",
                source="test",
                status=status,
                has_website=False,
                meets_rating_threshold=False,
                has_recent_reviews=False,
                is_candidate=False,
                created_at=datetime.utcnow()
            )
            self.db.add(lead)
            
        self.db.commit()
        
        # Verify all statuses were saved correctly
        leads = self.db.query(Lead).all()
        self.assertEqual(len(leads), len(LeadStatus))
        
        for lead in leads:
            self.assertIn(lead.status, LeadStatus)
            
        print(f"✓ All {len(LeadStatus)} status values stored correctly")
        
    def test_timeline_entry_type_field(self):
        """Test that timeline entries correctly store type values."""
        lead = Lead(
            id="timeline-test-lead",
            business_name="Timeline Test",
            phone="555-9999",
            industry="test",
            location="Test",
            source="test",
            status=LeadStatus.new,
            has_website=False,
            meets_rating_threshold=False,
            has_recent_reviews=False,
            is_candidate=False,
            created_at=datetime.utcnow()
        )
        self.db.add(lead)
        self.db.commit()
        
        # Create timeline entry
        entry = LeadTimelineEntry(
            id="test-entry-1",
            lead_id=lead.id,
            type=TimelineEntryType.STATUS_CHANGE,
            title="Status Changed",
            description="Test entry",
            previous_status=LeadStatus.new,
            new_status=LeadStatus.viewed,
            created_at=datetime.utcnow()
        )
        self.db.add(entry)
        self.db.commit()
        
        # Verify it was saved correctly
        saved_entry = self.db.query(LeadTimelineEntry).first()
        self.assertEqual(saved_entry.type, TimelineEntryType.STATUS_CHANGE)
        self.assertEqual(saved_entry.previous_status, LeadStatus.new)
        self.assertEqual(saved_entry.new_status, LeadStatus.viewed)
        
        print("✓ Timeline entries store enum values correctly")


class TestSchemaValidation(unittest.TestCase):
    """Test Pydantic schemas for consistency."""
    
    def test_conversion_scoring_response(self):
        """Test ConversionScoringResponse schema."""
        from schemas import ConversionScoringResponse
        
        # Test with minimal required fields
        response = ConversionScoringResponse(
            status="started",
            total_leads=100
        )
        self.assertEqual(response.status, "started")
        self.assertEqual(response.total_leads, 100)
        self.assertIsNone(response.scores_updated)
        self.assertIsNone(response.duration_seconds)
        
        # Test with all fields
        response = ConversionScoringResponse(
            status="completed",
            total_leads=100,
            scores_updated=95,
            duration_seconds=2.5,
            average_time_per_lead=0.026,
            message="Success",
            errors=["Warning: 5 leads skipped"],
            stats={"mean_score": 0.65}
        )
        self.assertEqual(response.scores_updated, 95)
        self.assertEqual(len(response.errors), 1)
        
        print("✓ ConversionScoringResponse schema works correctly")


def run_tests():
    """Run all tests."""
    print("=" * 60)
    print("SERVER UNIT TESTS")
    print("=" * 60)
    
    # Create test suite
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    
    # Add test classes
    suite.addTests(loader.loadTestsFromTestCase(TestEnumConsistency))
    suite.addTests(loader.loadTestsFromTestCase(TestConversionScoringService))
    suite.addTests(loader.loadTestsFromTestCase(TestAnalyticsEngine))
    suite.addTests(loader.loadTestsFromTestCase(TestDatabaseOperations))
    suite.addTests(loader.loadTestsFromTestCase(TestSchemaValidation))
    
    # Run tests
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    # Print summary
    print("\n" + "=" * 60)
    print("TEST SUMMARY")
    print("=" * 60)
    print(f"Tests run: {result.testsRun}")
    print(f"Failures: {len(result.failures)}")
    print(f"Errors: {len(result.errors)}")
    
    if result.failures:
        print("\nFailed tests:")
        for test, traceback in result.failures:
            print(f"  - {test}: {traceback.split('AssertionError:')[-1].strip()}")
            
    if result.errors:
        print("\nErrors:")
        for test, traceback in result.errors:
            print(f"  - {test}")
            # Print the actual error line
            lines = traceback.split('\n')
            for line in lines:
                if "AttributeError" in line or "CONVERTED" in line or "DNC" in line:
                    print(f"    ERROR: {line.strip()}")
    
    if len(result.failures) == 0 and len(result.errors) == 0:
        print("\n✅ ALL TESTS PASSED!")
        return 0
    else:
        print(f"\n❌ {len(result.failures) + len(result.errors)} tests failed")
        return 1


if __name__ == "__main__":
    exit(run_tests())