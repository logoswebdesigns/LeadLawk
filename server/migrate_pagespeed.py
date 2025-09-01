#!/usr/bin/env python3
"""
Migration script to add PageSpeed columns to existing database
"""

import sqlite3
import logging
from pathlib import Path

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def migrate_database():
    """Add PageSpeed columns to leads table"""
    
    # Database path
    db_path = Path("db/leadlawk.db")
    if not db_path.exists():
        logger.error(f"Database not found at {db_path}")
        return False
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    try:
        # Check if columns already exist
        cursor.execute("PRAGMA table_info(leads)")
        existing_columns = [col[1] for col in cursor.fetchall()]
        
        # List of new columns to add (must match models.py exactly)
        new_columns = [
            ("pagespeed_mobile_score", "INTEGER"),
            ("pagespeed_desktop_score", "INTEGER"),
            ("pagespeed_mobile_performance", "REAL"),
            ("pagespeed_desktop_performance", "REAL"),
            ("pagespeed_first_contentful_paint", "REAL"),
            ("pagespeed_largest_contentful_paint", "REAL"),
            ("pagespeed_total_blocking_time", "REAL"),
            ("pagespeed_cumulative_layout_shift", "REAL"),
            ("pagespeed_speed_index", "REAL"),
            ("pagespeed_time_to_interactive", "REAL"),
            ("pagespeed_accessibility_score", "INTEGER"),
            ("pagespeed_best_practices_score", "INTEGER"),
            ("pagespeed_seo_score", "INTEGER"),
            ("pagespeed_tested_at", "TIMESTAMP"),
            ("pagespeed_test_error", "TEXT")
        ]
        
        # Add columns that don't exist
        added_columns = []
        for column_name, column_type in new_columns:
            if column_name not in existing_columns:
                try:
                    cursor.execute(f"ALTER TABLE leads ADD COLUMN {column_name} {column_type}")
                    added_columns.append(column_name)
                    logger.info(f"Added column: {column_name}")
                except sqlite3.OperationalError as e:
                    if "duplicate column name" not in str(e).lower():
                        logger.error(f"Error adding column {column_name}: {e}")
        
        if added_columns:
            conn.commit()
            logger.info(f"Successfully added {len(added_columns)} PageSpeed columns")
        else:
            logger.info("All PageSpeed columns already exist")
        
        # Verify migration
        cursor.execute("PRAGMA table_info(leads)")
        final_columns = [col[1] for col in cursor.fetchall()]
        pagespeed_columns = [col for col in final_columns if 'pagespeed' in col.lower()]
        logger.info(f"Total PageSpeed columns in database: {len(pagespeed_columns)}")
        
        return True
        
    except Exception as e:
        logger.error(f"Migration failed: {e}")
        conn.rollback()
        return False
    finally:
        conn.close()

if __name__ == "__main__":
    success = migrate_database()
    if success:
        print("✅ PageSpeed migration completed successfully")
    else:
        print("❌ PageSpeed migration failed")
        exit(1)
