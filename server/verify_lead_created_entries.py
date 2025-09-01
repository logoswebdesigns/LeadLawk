#!/usr/bin/env python3
"""
Verify that all leads have a LEAD_CREATED timeline entry.
This is critical for tracking the full lead lifecycle.
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from models import Lead, LeadTimelineEntry, TimelineEntryType
from datetime import datetime

def verify_lead_created_entries():
    """Check all leads for LEAD_CREATED timeline entries."""
    
    # Connect to database
    engine = create_engine('sqlite:///db/leadloq.db', echo=False)
    Session = sessionmaker(bind=engine)
    session = Session()
    
    try:
        # Get all leads
        all_leads = session.query(Lead).all()
        total_leads = len(all_leads)
        print(f"\n📊 Total leads in database: {total_leads}")
        
        # Check each lead for LEAD_CREATED entry
        missing_entries = []
        has_entries = []
        multiple_entries = []
        
        for lead in all_leads:
            # Query for LEAD_CREATED entries for this lead
            created_entries = session.query(LeadTimelineEntry).filter(
                LeadTimelineEntry.lead_id == lead.id,
                LeadTimelineEntry.type == TimelineEntryType.LEAD_CREATED
            ).all()
            
            if len(created_entries) == 0:
                missing_entries.append(lead)
                print(f"  ❌ Missing: {lead.business_name} (ID: {lead.id})")
            elif len(created_entries) == 1:
                has_entries.append(lead)
            else:
                multiple_entries.append((lead, len(created_entries)))
                print(f"  ⚠️  Multiple ({len(created_entries)}): {lead.business_name} (ID: {lead.id})")
        
        # Report results
        print(f"\n📈 Summary:")
        print(f"  ✅ Leads with LEAD_CREATED entry: {len(has_entries)} ({len(has_entries)*100/total_leads:.1f}%)")
        print(f"  ❌ Missing LEAD_CREATED entry: {len(missing_entries)} ({len(missing_entries)*100/total_leads:.1f}%)")
        print(f"  ⚠️  Multiple LEAD_CREATED entries: {len(multiple_entries)}")
        
        # If there are missing entries, offer to create them
        if missing_entries:
            print(f"\n🔧 Found {len(missing_entries)} leads without LEAD_CREATED entries.")
            response = input("Would you like to create missing entries? (y/n): ")
            
            if response.lower() == 'y':
                created_count = 0
                for lead in missing_entries:
                    # Create LEAD_CREATED entry with the lead's creation time
                    entry = LeadTimelineEntry(
                        lead_id=lead.id,
                        type=TimelineEntryType.LEAD_CREATED,
                        title="Lead Created",
                        description=f"Lead {lead.business_name} was discovered and added to the system",
                        created_at=lead.created_at,  # Use the lead's creation timestamp
                        metadata={
                            'source': lead.source or 'unknown',
                            'industry': lead.industry,
                            'location': lead.location,
                            'has_website': lead.has_website,
                            'initial_status': 'NEW'
                        }
                    )
                    session.add(entry)
                    created_count += 1
                    
                    if created_count % 10 == 0:
                        print(f"    Created {created_count}/{len(missing_entries)} entries...")
                
                session.commit()
                print(f"\n✅ Successfully created {created_count} LEAD_CREATED entries!")
            else:
                print("❌ Skipped creating entries.")
        else:
            print("\n✅ All leads have LEAD_CREATED entries!")
        
        # Check for leads with multiple LEAD_CREATED entries
        if multiple_entries:
            print(f"\n⚠️  Found {len(multiple_entries)} leads with multiple LEAD_CREATED entries.")
            response = input("Would you like to keep only the earliest entry for each? (y/n): ")
            
            if response.lower() == 'y':
                cleaned_count = 0
                for lead, count in multiple_entries:
                    # Get all LEAD_CREATED entries for this lead
                    entries = session.query(LeadTimelineEntry).filter(
                        LeadTimelineEntry.lead_id == lead.id,
                        LeadTimelineEntry.type == TimelineEntryType.LEAD_CREATED
                    ).order_by(LeadTimelineEntry.created_at.asc()).all()
                    
                    # Keep the first one, delete the rest
                    for entry in entries[1:]:
                        session.delete(entry)
                        cleaned_count += 1
                
                session.commit()
                print(f"✅ Removed {cleaned_count} duplicate entries!")
        
        # Final verification
        print("\n🔍 Final verification:")
        final_check = session.query(Lead).outerjoin(
            LeadTimelineEntry,
            (Lead.id == LeadTimelineEntry.lead_id) & 
            (LeadTimelineEntry.type == TimelineEntryType.LEAD_CREATED)
        ).filter(
            LeadTimelineEntry.id.is_(None)
        ).count()
        
        if final_check == 0:
            print("✅ SUCCESS: All leads now have exactly one LEAD_CREATED timeline entry!")
        else:
            print(f"❌ WARNING: Still {final_check} leads without LEAD_CREATED entries.")
        
        # Show sample timeline for verification
        print("\n📋 Sample timeline entries (first 5 leads):")
        sample_leads = session.query(Lead).limit(5).all()
        for lead in sample_leads:
            entries = session.query(LeadTimelineEntry).filter(
                LeadTimelineEntry.lead_id == lead.id
            ).order_by(LeadTimelineEntry.created_at.asc()).all()
            
            print(f"\n  {lead.business_name}:")
            for entry in entries[:3]:  # Show first 3 entries
                print(f"    - {entry.type.value}: {entry.title} ({entry.created_at.strftime('%Y-%m-%d %H:%M')})")
            if len(entries) > 3:
                print(f"    ... and {len(entries) - 3} more entries")
                
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        session.close()

if __name__ == "__main__":
    print("=" * 60)
    print("LEAD CREATED TIMELINE ENTRY VERIFICATION")
    print("=" * 60)
    verify_lead_created_entries()