#!/usr/bin/env python3
"""Fix remaining DID NOT CONVERT entries."""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from database import SessionLocal
from models import LeadTimelineEntry, TimelineEntryType, LeadStatus

db = SessionLocal()
try:
    # Update all remaining NULL entries with "DID NOT CONVERT" in title
    entries = db.query(LeadTimelineEntry).filter(
        LeadTimelineEntry.type == TimelineEntryType.STATUS_CHANGE,
        LeadTimelineEntry.new_status == None,
        LeadTimelineEntry.title.contains("DID NOT CONVERT")
    ).all()
    
    print(f"Found {len(entries)} 'DID NOT CONVERT' entries to fix")
    
    for entry in entries:
        entry.new_status = LeadStatus.didNotConvert
    
    db.commit()
    print(f"✅ Fixed {len(entries)} entries")
    
    # Check remaining
    remaining = db.query(LeadTimelineEntry).filter(
        LeadTimelineEntry.type == TimelineEntryType.STATUS_CHANGE,
        LeadTimelineEntry.new_status == None
    ).count()
    
    print(f"📊 Remaining NULL new_status entries: {remaining}")
    
finally:
    db.close()