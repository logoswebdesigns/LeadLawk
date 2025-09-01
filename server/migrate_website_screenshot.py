#!/usr/bin/env python3
"""
Migration script to add website_screenshot_path column to leads table
"""

import sqlite3
import os
from datetime import datetime

def migrate_database():
    """Add website_screenshot_path column to existing database"""
    
    # Get database path
    db_path = '/app/db/leadloq.db' if os.getenv('USE_DOCKER') else './db/leadloq.db'
    
    if not os.path.exists(db_path):
        print(f"Database not found at {db_path}")
        return
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    try:
        # Check if column already exists
        cursor.execute("PRAGMA table_info(leads)")
        columns = [column[1] for column in cursor.fetchall()]
        
        if 'website_screenshot_path' not in columns:
            # Add the new column
            cursor.execute("""
                ALTER TABLE leads 
                ADD COLUMN website_screenshot_path VARCHAR
            """)
            conn.commit()
            print("✅ Added website_screenshot_path column to leads table")
        else:
            print("ℹ️ website_screenshot_path column already exists")
            
    except Exception as e:
        print(f"❌ Error during migration: {str(e)}")
        conn.rollback()
    finally:
        conn.close()

if __name__ == "__main__":
    migrate_database()