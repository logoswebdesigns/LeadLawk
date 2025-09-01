#!/usr/bin/env python3
"""
Test script to verify new lead animation is triggered
"""

import asyncio
import json
import time
from database import SessionLocal
from models import Lead, LeadStatus, LeadTimelineEntry, TimelineEntryType
import uuid
from datetime import datetime
from websocket_manager import pagespeed_websocket_manager

async def create_test_lead():
    """Create a test lead and broadcast via WebSocket"""
    db = SessionLocal()
    try:
        # Create a test lead
        lead = Lead(
            id=str(uuid.uuid4()),
            business_name=f"Test Business {datetime.now().strftime('%H%M%S')}",
            industry="Test Industry",
            rating=4.5,
            review_count=100,
            website_url="https://example.com",
            has_website=True,
            phone="123-456-7890",
            profile_url="https://maps.google.com/test",
            location="Test Location",
            status=LeadStatus.new
        )
        
        db.add(lead)
        db.commit()
        
        print(f"✅ Created test lead: {lead.business_name} (ID: {lead.id})")
        
        # Create timeline entry
        timeline_entry = LeadTimelineEntry(
            id=str(uuid.uuid4()),
            lead_id=lead.id,
            type=TimelineEntryType.LEAD_CREATED,
            title="Lead Created",
            description="Test lead created for animation testing",
            created_at=datetime.utcnow()
        )
        db.add(timeline_entry)
        db.commit()
        
        # Broadcast new lead via WebSocket
        await pagespeed_websocket_manager.broadcast_pagespeed_update(
            lead_id=lead.id,
            update_type="lead_created",
            data={
                "business_name": lead.business_name,
                "location": lead.location,
                "has_website": lead.has_website,
                "source": "test_script"
            }
        )
        
        print(f"📡 Broadcasted new lead notification")
        print(f"🎉 Animation should now appear in the UI!")
        print(f"\n⏰ Lead animation sequence (5 seconds total):")
        print(f"   - 0-1.2s: Fade in with scale animation")
        print(f"   - 1.2-3.8s: Full visibility with golden glow")
        print(f"   - 3.8-5s: Fade out")
        print(f"   - NO sheen effect (removed per request)")
        
        return lead.id
        
    except Exception as e:
        db.rollback()
        print(f"❌ Error creating test lead: {e}")
        return None
    finally:
        db.close()

async def main():
    print("🚀 Testing New Lead Animation")
    print("=" * 50)
    print("Make sure the Flutter app is running and on the leads list page")
    print("=" * 50)
    
    # Create a test lead
    lead_id = await create_test_lead()
    
    if lead_id:
        print(f"\n✨ Check the UI now to see the animation!")
        print(f"Lead ID: {lead_id}")
        
        # Wait a bit to let user see the animation
        print("\nWaiting 10 seconds for you to observe the animation...")
        await asyncio.sleep(10)
        
        print("\n✅ Test complete!")
        print("The animation should have:")
        print("  1. Faded in with scale effect (1.2s)")
        print("  2. Held at full visibility (2.6s)")
        print("  3. Faded away smoothly (1.2s)")
        print("  4. NO sheen effect (removed)")
        print("  5. Auto-refreshed without manual intervention")

if __name__ == "__main__":
    asyncio.run(main())