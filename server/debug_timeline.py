#!/usr/bin/env python3
"""
Debug script to check timeline entries in the database.
"""

from database import SessionLocal, engine
from models import Lead, LeadTimelineEntry
from sqlalchemy import text

def debug_timeline():
    db = SessionLocal()
    try:
        # Check if timeline entries exist
        entries_count = db.query(LeadTimelineEntry).count()
        print(f"Total timeline entries in database: {entries_count}")
        
        # Get a sample lead
        lead = db.query(Lead).first()
        if lead:
            print(f"\nLead: {lead.business_name} (ID: {lead.id})")
            
            # Check timeline entries for this lead
            direct_entries = db.query(LeadTimelineEntry).filter(LeadTimelineEntry.lead_id == lead.id).all()
            print(f"Direct timeline entries for this lead: {len(direct_entries)}")
            
            for entry in direct_entries:
                print(f"  - {entry.type}: {entry.title} (Created: {entry.created_at})")
            
            # Check via relationship
            print(f"Timeline entries via relationship: {len(lead.timeline_entries)}")
            for entry in lead.timeline_entries:
                print(f"  - {entry.type}: {entry.title} (Created: {entry.created_at})")
        
        # Show raw database structure
        with engine.connect() as conn:
            result = conn.execute(text("SELECT name FROM sqlite_master WHERE type='table'"))
            tables = result.fetchall()
            print(f"\nTables in database: {[t[0] for t in tables]}")
            
            result = conn.execute(text("SELECT COUNT(*) FROM lead_timeline_entries"))
            count = result.fetchone()[0]
            print(f"Timeline entries count (raw SQL): {count}")
            
            if count > 0:
                result = conn.execute(text("SELECT * FROM lead_timeline_entries LIMIT 3"))
                entries = result.fetchall()
                print("Sample timeline entries:")
                for entry in entries:
                    print(f"  {entry}")
    
    finally:
        db.close()

if __name__ == "__main__":
    debug_timeline()