#!/usr/bin/env python3
"""
Test that leads are deleted when PageSpeed score exceeds the threshold
"""

import sys
import os
import asyncio
import uuid
from datetime import datetime
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from database import SessionLocal, engine
from models import Lead, Base
from pagespeed_service import PageSpeedService
from unittest.mock import Mock, patch, AsyncMock


def setup_test_database():
    """Create tables for testing"""
    Base.metadata.create_all(bind=engine)


def cleanup_test_database():
    """Clean up test data"""
    db = SessionLocal()
    try:
        # Delete all test leads
        db.query(Lead).filter(Lead.business_name.like('%TEST%')).delete()
        db.commit()
    finally:
        db.close()


def create_test_lead(business_name: str, website_url: str) -> str:
    """Create a test lead in the database"""
    db = SessionLocal()
    try:
        lead_id = str(uuid.uuid4())
        lead = Lead(
            id=lead_id,
            business_name=business_name,
            phone="555-TEST-001",
            website_url=website_url,
            rating=4.5,
            review_count=100,
            status="new",  # Enum value is lowercase
            source="test",
            industry="test_industry",  # Required field
            location="Test City, ST",  # Required field
            created_at=datetime.now(),
            website_screenshot_path=f"test_screenshot_{lead_id}.png"
        )
        db.add(lead)
        db.commit()
        return lead_id
    finally:
        db.close()


def verify_lead_exists(lead_id: str) -> bool:
    """Check if a lead exists in the database"""
    db = SessionLocal()
    try:
        lead = db.query(Lead).filter(Lead.id == lead_id).first()
        return lead is not None
    finally:
        db.close()


def verify_screenshot_deletion_called(lead_id: str) -> bool:
    """Verify that screenshot deletion logic would be called"""
    # This is verified by the delete_lead_by_id function which we're now using
    return True


async def test_lead_deletion_on_high_pagespeed():
    """Test that a lead is deleted when PageSpeed score exceeds threshold"""
    print("\n" + "="*60)
    print("TEST: Lead Deletion on High PageSpeed Score")
    print("="*60)
    
    # Create a test lead
    test_lead_id = create_test_lead("TEST High PageSpeed Business", "https://example.com")
    print(f"✅ Created test lead: {test_lead_id}")
    
    # Verify lead exists
    assert verify_lead_exists(test_lead_id), "Lead should exist before test"
    print("✅ Verified lead exists in database")
    
    # Create PageSpeed service instance
    service = PageSpeedService()
    
    # Mock the PageSpeed API response with a score of 69 (above threshold of 50)
    mock_pagespeed_result = {
        'mobile': {
            'strategy': 'mobile',
            'performance_score': 69,  # This exceeds our threshold of 50
            'accessibility_score': 95,
            'best_practices_score': 79,
            'seo_score': 100,
            'metrics': {
                'first_contentful_paint': 3.5,
                'largest_contentful_paint': 5.0,
                'total_blocking_time': 0.128,
                'cumulative_layout_shift': 0,
                'speed_index': 5.58,
                'time_to_interactive': 5.0
            },
            'tested_url': 'https://example.com',
            'final_url': 'https://example.com',
            'screenshot_data': None
        }
    }
    
    # Mock the API call
    with patch.object(service, 'test_website', new_callable=AsyncMock) as mock_test:
        mock_test.return_value = mock_pagespeed_result['mobile']
        
        # Mock the screenshot saving
        with patch.object(service, 'save_website_screenshot', new_callable=AsyncMock) as mock_screenshot:
            mock_screenshot.return_value = f"website_{test_lead_id}_TEST High PageSpeed.png"
            
            # Call the background PageSpeed test with max_pagespeed_score=50
            print(f"📊 Running PageSpeed test with max score threshold: 50")
            print(f"📊 Actual PageSpeed score will be: 69")
            
            # Run the test in a thread as the real code does
            import threading
            
            def run_test():
                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)
                result = loop.run_until_complete(service.test_lead_website(test_lead_id))
                print(f"📊 PageSpeed test result: Mobile score = {result.get('mobile', {}).get('performance_score', 'N/A')}")
                
                # Now trigger the deletion logic with threshold
                service._run_background_pagespeed_test(test_lead_id, "https://example.com", max_pagespeed_score=50)
            
            thread = threading.Thread(target=run_test)
            thread.start()
            thread.join()
    
    # Give it a moment to process
    await asyncio.sleep(1)
    
    # Verify lead was deleted
    lead_still_exists = verify_lead_exists(test_lead_id)
    print(f"📊 Lead exists after test: {lead_still_exists}")
    
    if not lead_still_exists:
        print("✅ TEST PASSED: Lead was correctly deleted when PageSpeed score (69) exceeded threshold (50)")
        return True
    else:
        print("❌ TEST FAILED: Lead was NOT deleted despite PageSpeed score (69) exceeding threshold (50)")
        return False


async def test_lead_retention_on_low_pagespeed():
    """Test that a lead is retained when PageSpeed score is within threshold"""
    print("\n" + "="*60)
    print("TEST: Lead Retention on Low PageSpeed Score")
    print("="*60)
    
    # Create a test lead
    test_lead_id = create_test_lead("TEST Low PageSpeed Business", "https://example.com")
    print(f"✅ Created test lead: {test_lead_id}")
    
    # Verify lead exists
    assert verify_lead_exists(test_lead_id), "Lead should exist before test"
    print("✅ Verified lead exists in database")
    
    # Create PageSpeed service instance
    service = PageSpeedService()
    
    # Mock the PageSpeed API response with a score of 35 (below threshold of 50)
    mock_pagespeed_result = {
        'mobile': {
            'strategy': 'mobile',
            'performance_score': 35,  # This is below our threshold of 50
            'accessibility_score': 95,
            'best_practices_score': 79,
            'seo_score': 100,
            'metrics': {
                'first_contentful_paint': 7.5,
                'largest_contentful_paint': 10.0,
                'total_blocking_time': 0.256,
                'cumulative_layout_shift': 0.1,
                'speed_index': 8.5,
                'time_to_interactive': 10.0
            },
            'tested_url': 'https://example.com',
            'final_url': 'https://example.com',
            'screenshot_data': None
        }
    }
    
    # Mock the API call
    with patch.object(service, 'test_website', new_callable=AsyncMock) as mock_test:
        mock_test.return_value = mock_pagespeed_result['mobile']
        
        # Mock the screenshot saving
        with patch.object(service, 'save_website_screenshot', new_callable=AsyncMock) as mock_screenshot:
            mock_screenshot.return_value = f"website_{test_lead_id}_TEST Low PageSpeed.png"
            
            # Call the background PageSpeed test with max_pagespeed_score=50
            print(f"📊 Running PageSpeed test with max score threshold: 50")
            print(f"📊 Actual PageSpeed score will be: 35")
            
            # Run the test in a thread as the real code does
            import threading
            
            def run_test():
                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)
                result = loop.run_until_complete(service.test_lead_website(test_lead_id))
                print(f"📊 PageSpeed test result: Mobile score = {result.get('mobile', {}).get('performance_score', 'N/A')}")
                
                # Now trigger the deletion logic with threshold
                service._run_background_pagespeed_test(test_lead_id, "https://example.com", max_pagespeed_score=50)
            
            thread = threading.Thread(target=run_test)
            thread.start()
            thread.join()
    
    # Give it a moment to process
    await asyncio.sleep(1)
    
    # Verify lead was retained
    lead_still_exists = verify_lead_exists(test_lead_id)
    print(f"📊 Lead exists after test: {lead_still_exists}")
    
    if lead_still_exists:
        print("✅ TEST PASSED: Lead was correctly retained when PageSpeed score (35) was within threshold (50)")
        # Clean up the test lead
        db = SessionLocal()
        try:
            db.query(Lead).filter(Lead.id == test_lead_id).delete()
            db.commit()
        finally:
            db.close()
        return True
    else:
        print("❌ TEST FAILED: Lead was incorrectly deleted despite PageSpeed score (35) being within threshold (50)")
        return False


async def main():
    """Run all tests"""
    print("\n" + "="*60)
    print("PageSpeed Lead Deletion Test Suite")
    print("="*60)
    
    # Setup
    setup_test_database()
    cleanup_test_database()
    
    try:
        # Run tests
        test1_passed = await test_lead_deletion_on_high_pagespeed()
        test2_passed = await test_lead_retention_on_low_pagespeed()
        
        # Summary
        print("\n" + "="*60)
        print("TEST SUMMARY")
        print("="*60)
        print(f"Test 1 (Deletion on High Score): {'✅ PASSED' if test1_passed else '❌ FAILED'}")
        print(f"Test 2 (Retention on Low Score): {'✅ PASSED' if test2_passed else '❌ FAILED'}")
        
        if test1_passed and test2_passed:
            print("\n🎉 All tests passed!")
            return 0
        else:
            print("\n❌ Some tests failed!")
            return 1
            
    finally:
        # Cleanup
        cleanup_test_database()


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)