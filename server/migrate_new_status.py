#!/usr/bin/env python3
"""
Migration script to populate new_status field for existing STATUS_CHANGE timeline entries.
This script parses the title field to extract the status and populates the new_status field.
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from database import SessionLocal
from models import LeadTimelineEntry, TimelineEntryType, LeadStatus
import re


def migrate_new_status():
    """Migrate existing STATUS_CHANGE entries to populate new_status field"""
    db = SessionLocal()
    
    try:
        print("\n" + "="*60)
        print("🔄 Migrating new_status for STATUS_CHANGE Timeline Entries")
        print("="*60)
        
        # Get all STATUS_CHANGE entries with NULL new_status
        entries = db.query(LeadTimelineEntry).filter(
            LeadTimelineEntry.type == TimelineEntryType.STATUS_CHANGE,
            LeadTimelineEntry.new_status == None
        ).all()
        
        print(f"\n📊 Found {len(entries)} entries to migrate")
        
        if not entries:
            print("✅ No entries need migration!")
            return True
        
        # Status mapping from title text to enum
        status_map = {
            'NEW': LeadStatus.new,
            'VIEWED': LeadStatus.viewed,
            'CALLED': LeadStatus.called,
            'INTERESTED': LeadStatus.interested,
            'CONVERTED': LeadStatus.converted,
            'DID NOT CONVERT': LeadStatus.didNotConvert,
            'DIDNOTCONVERT': LeadStatus.didNotConvert,
            'DO NOT CALL': LeadStatus.doNotCall,
            'DONOTCALL': LeadStatus.doNotCall,
            'CALLBACK SCHEDULED': LeadStatus.callbackScheduled,
            'CALLBACKSCHEDULED': LeadStatus.callbackScheduled
        }
        
        migrated = 0
        failed = []
        
        for entry in entries:
            # Extract status from title using regex
            # Pattern: "Status changed to XXX" or similar
            match = re.search(r'Status changed to (.+?)(?:\s|$)', entry.title, re.IGNORECASE)
            
            if match:
                status_text = match.group(1).strip().upper()
                
                # Try to find matching status
                new_status = status_map.get(status_text)
                
                if new_status:
                    entry.new_status = new_status
                    migrated += 1
                    print(f"   ✅ Migrated: {entry.id[:8]}... -> {new_status.value}")
                else:
                    failed.append((entry.id, entry.title, status_text))
                    print(f"   ⚠️ Unknown status: '{status_text}' in '{entry.title}'")
            else:
                # Try alternative pattern for special cases
                if 'CALLED' in entry.title.upper():
                    entry.new_status = LeadStatus.called
                    migrated += 1
                    print(f"   ✅ Migrated (pattern 2): {entry.id[:8]}... -> called")
                elif 'VIEWED' in entry.title.upper():
                    entry.new_status = LeadStatus.viewed
                    migrated += 1
                    print(f"   ✅ Migrated (pattern 2): {entry.id[:8]}... -> viewed")
                elif 'INTERESTED' in entry.title.upper():
                    entry.new_status = LeadStatus.interested
                    migrated += 1
                    print(f"   ✅ Migrated (pattern 2): {entry.id[:8]}... -> interested")
                elif 'CONVERTED' in entry.title.upper() and 'NOT' not in entry.title.upper():
                    entry.new_status = LeadStatus.converted
                    migrated += 1
                    print(f"   ✅ Migrated (pattern 2): {entry.id[:8]}... -> converted")
                elif 'DID NOT CONVERT' in entry.title.upper() or 'DIDNOTCONVERT' in entry.title.upper():
                    entry.new_status = LeadStatus.didNotConvert
                    migrated += 1
                    print(f"   ✅ Migrated (pattern 2): {entry.id[:8]}... -> didNotConvert")
                else:
                    failed.append((entry.id, entry.title, "NO_MATCH"))
                    print(f"   ❌ Could not parse: '{entry.title}'")
        
        # Commit the changes
        db.commit()
        
        print("\n" + "="*60)
        print("📊 Migration Summary")
        print("="*60)
        print(f"✅ Successfully migrated: {migrated} entries")
        print(f"❌ Failed to migrate: {len(failed)} entries")
        
        if failed:
            print("\n⚠️ Failed entries:")
            for entry_id, title, extracted in failed[:10]:  # Show first 10
                print(f"   - {entry_id[:8]}...: '{title}' (extracted: '{extracted}')")
        
        # Verify no NULL new_status remains for successfully migrated
        remaining = db.query(LeadTimelineEntry).filter(
            LeadTimelineEntry.type == TimelineEntryType.STATUS_CHANGE,
            LeadTimelineEntry.new_status == None
        ).count()
        
        print(f"\n📊 Remaining NULL new_status entries: {remaining}")
        
        if remaining == 0:
            print("🎉 All STATUS_CHANGE entries now have new_status populated!")
            return True
        elif remaining < len(entries):
            print(f"✅ Reduced NULL entries from {len(entries)} to {remaining}")
            return True
        else:
            print("⚠️ Migration had no effect")
            return False
            
    except Exception as e:
        print(f"\n❌ Migration failed: {e}")
        db.rollback()
        return False
    finally:
        db.close()


if __name__ == "__main__":
    success = migrate_new_status()
    sys.exit(0 if success else 1)