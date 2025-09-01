"""
Migration script to add sales pitch support to the database
"""
import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from datetime import datetime
import uuid

DATABASE_URL = "sqlite:///./db/leadloq.db"
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def migrate():
    db = SessionLocal()
    try:
        # Create sales_pitches table
        db.execute(text("""
            CREATE TABLE IF NOT EXISTS sales_pitches (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                content TEXT NOT NULL,
                is_active BOOLEAN DEFAULT 1,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                conversions INTEGER DEFAULT 0,
                attempts INTEGER DEFAULT 0,
                conversion_rate FLOAT DEFAULT 0.0
            )
        """))
        
        # Add sales_pitch_id to leads table
        try:
            db.execute(text("ALTER TABLE leads ADD COLUMN sales_pitch_id TEXT"))
        except:
            print("Column sales_pitch_id already exists in leads table")
        
        # Add sales_pitch_id to call_logs table  
        try:
            db.execute(text("ALTER TABLE call_logs ADD COLUMN sales_pitch_id TEXT"))
        except:
            print("Column sales_pitch_id already exists in call_logs table")
        
        # Create default sales pitches if none exist
        pitches_count = db.execute(text("SELECT COUNT(*) FROM sales_pitches")).scalar()
        
        if pitches_count == 0:
            # Create Pitch A - Direct approach
            pitch_a_id = str(uuid.uuid4())
            db.execute(text("""
                INSERT INTO sales_pitches (id, name, content)
                VALUES (:id, :name, :content)
            """), {
                "id": pitch_a_id,
                "name": "Pitch A: Direct Value",
                "content": "Hi [Business Name], I noticed you don't have a website yet. "
                          "I help small businesses like yours get online with professional "
                          "websites that bring in more customers. Would you be interested "
                          "in a quick 5-minute chat about how this could help your business?"
            })
            
            # Create Pitch B - Problem-focused approach
            pitch_b_id = str(uuid.uuid4())
            db.execute(text("""
                INSERT INTO sales_pitches (id, name, content)
                VALUES (:id, :name, :content)
            """), {
                "id": pitch_b_id,
                "name": "Pitch B: Problem Solver",
                "content": "Hi [Business Name], I work with local businesses in [Location] "
                          "and noticed potential customers might have trouble finding you online. "
                          "A professional website could fix that and help you compete with larger "
                          "companies. Can we talk for 5 minutes about growing your online presence?"
            })
            
            print("Created 2 default sales pitches")
        
        db.commit()
        print("Migration completed successfully!")
        
    except Exception as e:
        print(f"Error during migration: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    migrate()