"""
Add conversion failure tracking fields to leads table
"""
import sqlite3
from datetime import datetime

def migrate():
    """Add conversion failure tracking columns to leads table"""
    
    # Connect to the database
    conn = sqlite3.connect('db/leadloq.db')
    cursor = conn.cursor()
    
    try:
        # Check if columns already exist
        cursor.execute("PRAGMA table_info(leads)")
        columns = [col[1] for col in cursor.fetchall()]
        
        # Add conversion_failure_reason column if it doesn't exist
        if 'conversion_failure_reason' not in columns:
            cursor.execute("""
                ALTER TABLE leads 
                ADD COLUMN conversion_failure_reason VARCHAR
            """)
            print("✅ Added conversion_failure_reason column")
        
        # Add conversion_failure_notes column if it doesn't exist  
        if 'conversion_failure_notes' not in columns:
            cursor.execute("""
                ALTER TABLE leads 
                ADD COLUMN conversion_failure_notes TEXT
            """)
            print("✅ Added conversion_failure_notes column")
            
        # Add conversion_failure_date column if it doesn't exist
        if 'conversion_failure_date' not in columns:
            cursor.execute("""
                ALTER TABLE leads 
                ADD COLUMN conversion_failure_date DATETIME
            """)
            print("✅ Added conversion_failure_date column")
        
        # Commit the changes
        conn.commit()
        print(f"✅ Migration completed successfully at {datetime.now()}")
        
    except Exception as e:
        print(f"❌ Migration failed: {e}")
        conn.rollback()
        raise
    finally:
        conn.close()

if __name__ == "__main__":
    migrate()