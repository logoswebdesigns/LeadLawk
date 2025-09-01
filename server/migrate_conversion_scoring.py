#!/usr/bin/env python3
"""
Migration script to add conversion scoring fields to the database.
"""

import sqlite3
import sys
from datetime import datetime

def migrate_database():
    """Add conversion scoring fields to leads table and create conversion_model table."""
    
    db_path = "/app/db/leadloq.db" if len(sys.argv) < 2 else sys.argv[1]
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    try:
        # Add conversion scoring fields to leads table
        print("Adding conversion scoring fields to leads table...")
        
        # Check if columns already exist
        cursor.execute("PRAGMA table_info(leads)")
        columns = [col[1] for col in cursor.fetchall()]
        
        if 'conversion_score' not in columns:
            cursor.execute("""
                ALTER TABLE leads 
                ADD COLUMN conversion_score REAL
            """)
            print("✓ Added conversion_score column")
        
        if 'conversion_score_calculated_at' not in columns:
            cursor.execute("""
                ALTER TABLE leads 
                ADD COLUMN conversion_score_calculated_at TIMESTAMP
            """)
            print("✓ Added conversion_score_calculated_at column")
        
        if 'conversion_score_factors' not in columns:
            cursor.execute("""
                ALTER TABLE leads 
                ADD COLUMN conversion_score_factors TEXT
            """)
            print("✓ Added conversion_score_factors column")
        
        # Create index for conversion_score
        cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_leads_conversion_score 
            ON leads(conversion_score)
        """)
        print("✓ Created index on conversion_score")
        
        # Create conversion_model table
        print("\nCreating conversion_model table...")
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS conversion_model (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                model_version VARCHAR NOT NULL,
                feature_weights TEXT NOT NULL,
                feature_importance TEXT,
                model_accuracy REAL,
                training_samples INTEGER,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                is_active BOOLEAN DEFAULT 1,
                total_conversions INTEGER DEFAULT 0,
                total_leads INTEGER DEFAULT 0,
                baseline_conversion_rate REAL,
                precision_score REAL,
                recall_score REAL,
                f1_score REAL
            )
        """)
        print("✓ Created conversion_model table")
        
        conn.commit()
        print("\n✅ Migration completed successfully!")
        
    except Exception as e:
        print(f"\n❌ Migration failed: {e}")
        conn.rollback()
        raise
    finally:
        conn.close()

if __name__ == "__main__":
    migrate_database()