#!/usr/bin/env python3
"""
Database migration script to add timeline support to existing LeadLawk database.
"""

from database import engine, SessionLocal, init_db
from models import Lead, LeadTimelineEntry, TimelineEntryType, LeadStatus
from datetime import datetime
import uuid
import sqlite3
from pathlib import Path


def add_missing_columns():
    """Add missing columns to existing tables."""
    db_path = Path("db/leadlawk.db")
    if not db_path.exists():
        print("Database file not found, skipping column migration.")
        return
    
    conn = sqlite3.connect(str(db_path))
    cursor = conn.cursor()
    
    try:
        # Check if follow_up_date column exists
        cursor.execute("PRAGMA table_info(leads)")
        columns = [row[1] for row in cursor.fetchall()]
        
        if 'follow_up_date' not in columns:
            print("Adding follow_up_date column to leads table...")
            cursor.execute("ALTER TABLE leads ADD COLUMN follow_up_date DATETIME")
            conn.commit()
            print("follow_up_date column added successfully!")
        else:
            print("follow_up_date column already exists.")
            
        # Check if screenshot_path column exists
        if 'screenshot_path' not in columns:
            print("Adding screenshot_path column to leads table...")
            cursor.execute("ALTER TABLE leads ADD COLUMN screenshot_path TEXT")
            conn.commit()
            print("screenshot_path column added successfully!")
        else:
            print("screenshot_path column already exists.")
            
    except Exception as e:
        print(f"Error adding columns: {e}")
        conn.rollback()
    finally:
        conn.close()


def add_lead_created_entries():
    """Add 'Lead Created' timeline entries for all existing leads."""
    db = SessionLocal()
    try:
        # Get all leads that don't have a lead_created timeline entry
        leads = db.query(Lead).all()
        
        for lead in leads:
            # Check if lead already has a lead_created entry
            existing_entry = db.query(LeadTimelineEntry).filter(
                LeadTimelineEntry.lead_id == lead.id,
                LeadTimelineEntry.type == TimelineEntryType.LEAD_CREATED
            ).first()
            
            if not existing_entry:
                # Create lead_created entry
                timeline_entry = LeadTimelineEntry(
                    id=f"{lead.id}_created",
                    lead_id=lead.id,
                    type=TimelineEntryType.LEAD_CREATED,
                    title="Lead Generated",
                    description=f"Lead discovered and added to pipeline from {lead.source}",
                    created_at=lead.created_at,
                )
                db.add(timeline_entry)
                print(f"Added lead_created entry for: {lead.business_name}")
        
        db.commit()
        print(f"Migration completed! Added timeline entries for {len(leads)} leads.")
        
    except Exception as e:
        print(f"Migration error: {e}")
        db.rollback()
    finally:
        db.close()


def main():
    print("Starting database migration for timeline support...")
    
    # Add missing columns to existing tables
    print("Adding missing columns...")
    add_missing_columns()
    
    # Create new tables
    print("Creating new tables...")
    init_db()
    print("Tables created successfully!")
    
    # Add timeline entries for existing leads
    print("Adding lead_created entries for existing leads...")
    add_lead_created_entries()
    
    print("Migration completed successfully!")


if __name__ == "__main__":
    main()