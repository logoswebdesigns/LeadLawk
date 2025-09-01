#!/usr/bin/env python3
"""
Migration script to fix incorrect status values in the database.
Converts snake_case status values to camelCase format.
"""

from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
import os

# Database configuration
db_path = os.path.join(os.path.dirname(__file__), "db", "leadloq.db")
DATABASE_URL = f"sqlite:///{db_path}"

def fix_status_values():
    """Fix incorrect status values in the database."""
    engine = create_engine(DATABASE_URL)
    
    # Status mappings from incorrect to correct format
    status_mappings = {
        'do_not_call': 'doNotCall',
        'callback_scheduled': 'callbackScheduled',
        'did_not_convert': 'didNotConvert'
    }
    
    with engine.connect() as conn:
        # Start a transaction
        trans = conn.begin()
        try:
            # Fix leads table
            for old_status, new_status in status_mappings.items():
                result = conn.execute(
                    text("UPDATE leads SET status = :new_status WHERE status = :old_status"),
                    {"new_status": new_status, "old_status": old_status}
                )
                if result.rowcount > 0:
                    print(f"✓ Updated {result.rowcount} leads from '{old_status}' to '{new_status}'")
            
            # Fix timeline entries table (previous_status and new_status columns)
            for old_status, new_status in status_mappings.items():
                # Fix previous_status column
                result = conn.execute(
                    text("UPDATE lead_timeline_entries SET previous_status = :new_status WHERE previous_status = :old_status"),
                    {"new_status": new_status, "old_status": old_status}
                )
                if result.rowcount > 0:
                    print(f"✓ Updated {result.rowcount} timeline entries (previous_status) from '{old_status}' to '{new_status}'")
                
                # Fix new_status column
                result = conn.execute(
                    text("UPDATE lead_timeline_entries SET new_status = :new_status WHERE new_status = :old_status"),
                    {"new_status": new_status, "old_status": old_status}
                )
                if result.rowcount > 0:
                    print(f"✓ Updated {result.rowcount} timeline entries (new_status) from '{old_status}' to '{new_status}'")
            
            # Commit the transaction
            trans.commit()
            print("\n✅ Database migration completed successfully!")
            
        except Exception as e:
            trans.rollback()
            print(f"\n❌ Error during migration: {e}")
            raise

if __name__ == "__main__":
    print("=" * 60)
    print("STATUS VALUE MIGRATION")
    print("=" * 60)
    print("\nFixing incorrect status values in database...")
    fix_status_values()