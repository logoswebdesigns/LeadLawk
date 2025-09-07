#!/usr/bin/env python3
"""
Database migration script for blacklist feature
Creates blacklist table and updates Lead model
"""

import sqlite3
import sys
from pathlib import Path

def migrate_database():
    """Apply blacklist migration to database"""
    
    # Database path
    db_path = Path("db/leadloq.db")
    if not db_path.exists():
        print(f"Database not found at {db_path}")
        return False
    
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Create blacklisted_businesses table
        print("Creating blacklisted_businesses table...")
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS blacklisted_businesses (
                id TEXT PRIMARY KEY,
                business_name TEXT NOT NULL UNIQUE,
                reason TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                notes TEXT
            )
        """)
        
        # Create index on business_name for fast lookups
        cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_blacklisted_business_name 
            ON blacklisted_businesses(business_name)
        """)
        
        # Add new columns to leads table if they don't exist
        print("Updating leads table...")
        
        # Check existing columns
        cursor.execute("PRAGMA table_info(leads)")
        existing_columns = [col[1] for col in cursor.fetchall()]
        
        # Add is_franchise column if it doesn't exist
        if 'is_franchise' not in existing_columns:
            cursor.execute("""
                ALTER TABLE leads ADD COLUMN is_franchise BOOLEAN DEFAULT 0
            """)
            print("Added is_franchise column to leads table")
        
        # Add exclusion_reason column if it doesn't exist
        if 'exclusion_reason' not in existing_columns:
            cursor.execute("""
                ALTER TABLE leads ADD COLUMN exclusion_reason TEXT
            """)
            print("Added exclusion_reason column to leads table")
        
        conn.commit()
        print("Migration completed successfully!")
        
        # Show current state
        cursor.execute("SELECT COUNT(*) FROM blacklisted_businesses")
        blacklist_count = cursor.fetchone()[0]
        print(f"Current blacklist entries: {blacklist_count}")
        
        conn.close()
        return True
        
    except Exception as e:
        print(f"Migration failed: {e}")
        if conn:
            conn.rollback()
            conn.close()
        return False


def rollback_migration():
    """Rollback the blacklist migration"""
    
    db_path = Path("db/leadloq.db")
    if not db_path.exists():
        print(f"Database not found at {db_path}")
        return False
    
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Drop blacklisted_businesses table
        cursor.execute("DROP TABLE IF EXISTS blacklisted_businesses")
        print("Dropped blacklisted_businesses table")
        
        # Note: We can't easily remove columns from SQLite, would need to recreate table
        # For now, just leaving the columns in place as they won't harm anything
        
        conn.commit()
        conn.close()
        print("Rollback completed")
        return True
        
    except Exception as e:
        print(f"Rollback failed: {e}")
        return False


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--rollback":
        rollback_migration()
    else:
        migrate_database()