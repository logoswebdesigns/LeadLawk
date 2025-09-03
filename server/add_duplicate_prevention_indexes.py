#!/usr/bin/env python3
"""
Add indexes for efficient duplicate lead detection
"""

from sqlalchemy import create_engine, text, Index
from sqlalchemy.orm import sessionmaker
from database import SessionLocal, engine
from models import Lead, Base
import sys

def add_duplicate_prevention_indexes():
    """Add compound indexes for efficient duplicate detection"""
    
    session = SessionLocal()
    
    try:
        print("🔍 Adding indexes for duplicate prevention...")
        
        # Create compound index for business_name + location (most common duplicate check)
        # Using functional index for case-insensitive matching
        print("   Creating index: ix_leads_business_location...")
        session.execute(text("""
            CREATE INDEX IF NOT EXISTS ix_leads_business_location 
            ON leads (LOWER(business_name), LOWER(location))
        """))
        
        # Index for profile_url (unique identifier from Google Maps)
        print("   Creating index: ix_leads_profile_url...")
        session.execute(text("""
            CREATE INDEX IF NOT EXISTS ix_leads_profile_url 
            ON leads (profile_url)
        """))
        
        # Compound index for phone + location
        print("   Creating index: ix_leads_phone_location...")
        session.execute(text("""
            CREATE INDEX IF NOT EXISTS ix_leads_phone_location 
            ON leads (phone, LOWER(location))
        """))
        
        # Additional index for efficient sorting and filtering
        print("   Creating index: ix_leads_status_created...")
        session.execute(text("""
            CREATE INDEX IF NOT EXISTS ix_leads_status_created 
            ON leads (status, created_at DESC)
        """))
        
        session.commit()
        print("✅ All indexes created successfully!")
        
        # Verify indexes were created
        print("\n📊 Verifying indexes:")
        result = session.execute(text("""
            SELECT name, tbl_name 
            FROM sqlite_master 
            WHERE type = 'index' 
            AND tbl_name = 'leads'
            ORDER BY name
        """))
        
        for row in result:
            print(f"   - {row[0]}")
        
        # Get duplicate statistics
        print("\n📈 Checking for existing duplicates:")
        
        # Check duplicates by business_name + location
        duplicates = session.execute(text("""
            SELECT 
                LOWER(business_name) as name, 
                LOWER(location) as loc, 
                COUNT(*) as count
            FROM leads
            GROUP BY LOWER(business_name), LOWER(location)
            HAVING COUNT(*) > 1
            ORDER BY count DESC
            LIMIT 10
        """))
        
        dup_count = 0
        for row in duplicates:
            dup_count += 1
            print(f"   ⚠️ '{row[0]}' in '{row[1]}': {row[2]} duplicates")
        
        if dup_count == 0:
            print("   ✅ No duplicates found!")
        else:
            print(f"\n   Found {dup_count} sets of duplicates (showing top 10)")
            
            # Optional: Clean up duplicates (keeping the oldest one)
            response = input("\n   Would you like to remove duplicate leads? (y/n): ")
            if response.lower() == 'y':
                remove_duplicates(session)
        
        return True
        
    except Exception as e:
        print(f"❌ Error adding indexes: {e}")
        session.rollback()
        return False
    finally:
        session.close()

def remove_duplicates(session):
    """Remove duplicate leads, keeping the oldest (first created) one"""
    
    print("\n🧹 Removing duplicate leads...")
    
    try:
        # Find and remove duplicates
        result = session.execute(text("""
            WITH duplicates AS (
                SELECT 
                    id,
                    business_name,
                    location,
                    created_at,
                    ROW_NUMBER() OVER (
                        PARTITION BY LOWER(business_name), LOWER(location) 
                        ORDER BY created_at ASC
                    ) as rn
                FROM leads
            )
            SELECT id, business_name, location
            FROM duplicates
            WHERE rn > 1
        """))
        
        ids_to_delete = []
        for row in result:
            ids_to_delete.append(row[0])
            print(f"   Removing duplicate: {row[1]} in {row[2]} (ID: {row[0]})")
        
        if ids_to_delete:
            # Delete timeline entries for duplicate leads first
            session.execute(text("""
                DELETE FROM lead_timeline_entries 
                WHERE lead_id IN :ids
            """), {"ids": tuple(ids_to_delete)})
            
            # Delete the duplicate leads
            session.execute(text("""
                DELETE FROM leads 
                WHERE id IN :ids
            """), {"ids": tuple(ids_to_delete)})
            
            session.commit()
            print(f"   ✅ Removed {len(ids_to_delete)} duplicate leads")
        else:
            print("   ✅ No duplicates to remove")
            
    except Exception as e:
        print(f"   ❌ Error removing duplicates: {e}")
        session.rollback()

if __name__ == "__main__":
    success = add_duplicate_prevention_indexes()
    sys.exit(0 if success else 1)