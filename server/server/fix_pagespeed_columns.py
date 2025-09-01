#!/usr/bin/env python3
"""
Fix PageSpeed columns to match models.py
"""

import sqlite3
from pathlib import Path

db_path = Path("db/leadlawk.db")
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

try:
    # First, check current columns
    cursor.execute("PRAGMA table_info(leads)")
    columns = [col[1] for col in cursor.fetchall()]
    
    # Drop incorrect columns if they exist
    incorrect_columns = [
        'pagespeed_mobile_accessibility',
        'pagespeed_desktop_accessibility', 
        'pagespeed_mobile_best_practices',
        'pagespeed_desktop_best_practices',
        'pagespeed_mobile_seo',
        'pagespeed_desktop_seo'
    ]
    
    # SQLite doesn't support DROP COLUMN directly, so we need to recreate the table
    # But let's just add the missing columns instead
    
    # Add missing columns that match models.py
    missing_columns = [
        ("pagespeed_accessibility_score", "INTEGER"),
        ("pagespeed_best_practices_score", "INTEGER"),
        ("pagespeed_seo_score", "INTEGER")
    ]
    
    for col_name, col_type in missing_columns:
        if col_name not in columns:
            try:
                cursor.execute(f"ALTER TABLE leads ADD COLUMN {col_name} {col_type}")
                print(f"Added column: {col_name}")
            except sqlite3.OperationalError as e:
                if "duplicate column" not in str(e).lower():
                    print(f"Error adding {col_name}: {e}")
    
    conn.commit()
    print("✅ Fixed PageSpeed columns")
    
except Exception as e:
    print(f"❌ Error: {e}")
    conn.rollback()
finally:
    conn.close()
