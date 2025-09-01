#!/usr/bin/env python3
"""
Migration script to add LEAD_CREATED timeline entries for existing leads that don't have them.
"""

from database import SessionLocal, engine
from models import Lead, LeadTimelineEntry, TimelineEntryType
from sqlalchemy import and_, select, func
from datetime import datetime
import uuid

def add_missing_lead_created_entries():
    """Add LEAD_CREATED timeline entries for leads that don't have them"""
    db = SessionLocal()
    
    try:
        # Get all leads
        all_leads = db.query(Lead).all()
        print(f"Found {len(all_leads)} total leads")
        
        # Count how many need creation entries
        missing_count = 0
        added_count = 0
        
        for lead in all_leads:
            # Check if this lead has a LEAD_CREATED entry
            existing_entry = db.query(LeadTimelineEntry).filter(
                and_(
                    LeadTimelineEntry.lead_id == lead.id,
                    LeadTimelineEntry.type == TimelineEntryType.LEAD_CREATED
                )
            ).first()
            
            if not existing_entry:
                missing_count += 1
                print(f"  Missing creation entry for: {lead.business_name} (ID: {lead.id})")
                
                # Create the missing entry
                timeline_entry = LeadTimelineEntry(
                    id=str(uuid.uuid4()),
                    lead_id=lead.id,
                    type=TimelineEntryType.LEAD_CREATED,
                    title="Lead Created",
                    description=f"Lead discovered from {lead.industry} search in {lead.location}. {'Has website' if lead.has_website else 'No website (candidate)'}",
                    created_at=lead.created_at  # Use the lead's creation date
                )
                db.add(timeline_entry)
                added_count += 1
                print(f"    ✅ Added creation entry dated: {lead.created_at}")
        
        if missing_count > 0:
            db.commit()
            print(f"\n✅ Migration complete!")
            print(f"  - {missing_count} leads were missing creation entries")
            print(f"  - {added_count} creation entries added")
        else:
            print("\n✅ All leads already have creation entries. No migration needed.")
            
    except Exception as e:
        db.rollback()
        print(f"\n❌ Migration failed: {str(e)}")
        raise
    finally:
        db.close()

def verify_migration():
    """Verify that all leads now have creation entries"""
    db = SessionLocal()
    
    try:
        # Count total leads
        total_leads = db.query(func.count(Lead.id)).scalar()
        
        # Count leads with LEAD_CREATED entries
        leads_with_creation = db.query(func.count(func.distinct(LeadTimelineEntry.lead_id))).filter(
            LeadTimelineEntry.type == TimelineEntryType.LEAD_CREATED
        ).scalar()
        
        print(f"\n📊 Verification Results:")
        print(f"  Total leads: {total_leads}")
        print(f"  Leads with creation entries: {leads_with_creation}")
        
        if total_leads == leads_with_creation:
            print("  ✅ All leads have creation entries!")
            return True
        else:
            missing = total_leads - leads_with_creation
            print(f"  ⚠️ {missing} leads still missing creation entries")
            return False
            
    finally:
        db.close()

if __name__ == "__main__":
    print("🔄 Starting Lead Creation Entry Migration")
    print("="*50)
    
    # Run migration
    add_missing_lead_created_entries()
    
    # Verify results
    verify_migration()