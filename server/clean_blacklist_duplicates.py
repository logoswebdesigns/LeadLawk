#!/usr/bin/env python3
"""
Add unique constraint to blacklist table to prevent exact duplicate business names.
"""

import sqlite3
from datetime import datetime

def enforce_blacklist_uniqueness():
    """Add unique constraint to blacklist table."""
    
    # Connect to the database
    conn = sqlite3.connect('db/leadloq.db')
    cursor = conn.cursor()
    
    try:
        # First check for exact duplicates
        cursor.execute("""
            SELECT business_name, COUNT(*) as count
            FROM blacklist 
            GROUP BY business_name
            HAVING COUNT(*) > 1
        """)
        duplicates = cursor.fetchall()
        
        if duplicates:
            print(f"Found {len(duplicates)} exact duplicate business names:")
            for name, count in duplicates:
                print(f"  - {name}: {count} entries")
                
                # Keep the oldest entry, delete newer duplicates
                cursor.execute("""
                    DELETE FROM blacklist 
                    WHERE business_name = ? 
                    AND rowid NOT IN (
                        SELECT MIN(rowid) 
                        FROM blacklist 
                        WHERE business_name = ?
                    )
                """, (name, name))
            
            deleted_count = conn.total_changes
            conn.commit()
            print(f"\nDeleted {deleted_count} duplicate entries")
        else:
            print("No exact duplicates found in blacklist")
        
        # Check if unique constraint already exists
        cursor.execute("""
            SELECT sql FROM sqlite_master 
            WHERE type='table' AND name='blacklist'
        """)
        table_sql = cursor.fetchone()[0]
        
        if 'UNIQUE' not in table_sql.upper() or 'unique(business_name)' not in table_sql.lower().replace(' ', ''):
            print("\nAdding unique constraint to blacklist table...")
            
            # Create new table with unique constraint
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS blacklist_new (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    business_name TEXT NOT NULL UNIQUE,
                    reason TEXT NOT NULL,
                    notes TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            
            # Copy data to new table (this will fail if duplicates still exist)
            cursor.execute("""
                INSERT INTO blacklist_new (business_name, reason, notes, created_at)
                SELECT business_name, reason, notes, created_at FROM blacklist
            """)
            
            # Drop old table and rename new one
            cursor.execute("DROP TABLE blacklist")
            cursor.execute("ALTER TABLE blacklist_new RENAME TO blacklist")
            
            conn.commit()
            print("✅ Unique constraint added successfully!")
        else:
            print("\n✅ Unique constraint already exists on business_name")
        
        # Verify final count
        cursor.execute("SELECT COUNT(*) FROM blacklist")
        final_count = cursor.fetchone()[0]
        print(f"\nFinal blacklist count: {final_count} unique businesses")
        
        # Show some entries as verification
        cursor.execute("SELECT business_name FROM blacklist ORDER BY created_at DESC LIMIT 5")
        recent = cursor.fetchall()
        print("\nMost recent blacklist entries:")
        for name, in recent:
            print(f"  - {name}")
        
    except Exception as e:
        print(f"Error: {e}")
        conn.rollback()
        raise
    finally:
        conn.close()

if __name__ == "__main__":
    enforce_blacklist_uniqueness()