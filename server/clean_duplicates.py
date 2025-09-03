#!/usr/bin/env python3
"""
Clean up duplicate leads from the database
Keeps the oldest (first created) lead and removes newer duplicates
"""

from sqlalchemy import text
from database import SessionLocal
import sys

def clean_duplicate_leads():
    """Remove duplicate leads, keeping the oldest one"""
    
    session = SessionLocal()
    
    try:
        print("🔍 Analyzing duplicate leads in database...")
        
        # First, get statistics on duplicates
        duplicates_query = text("""
            SELECT 
                LOWER(business_name) as name, 
                LOWER(location) as loc, 
                COUNT(*) as count,
                GROUP_CONCAT(id, '|') as ids,
                GROUP_CONCAT(status, '|') as statuses,
                MIN(created_at) as first_created,
                MAX(created_at) as last_created
            FROM leads
            GROUP BY LOWER(business_name), LOWER(location)
            HAVING COUNT(*) > 1
            ORDER BY count DESC
        """)
        
        duplicates = session.execute(duplicates_query).fetchall()
        
        if not duplicates:
            print("✅ No duplicate leads found!")
            return True
        
        total_duplicates = sum(row[2] - 1 for row in duplicates)  # -1 because we keep one
        print(f"\n📊 Found {len(duplicates)} sets of duplicates ({total_duplicates} leads to remove)")
        
        # Show top 10 duplicates
        print("\n📋 Top duplicate leads:")
        for i, row in enumerate(duplicates[:10]):
            name, location, count, ids, statuses, first, last = row
            print(f"   {i+1}. '{name}' in '{location}': {count} copies")
            print(f"      Statuses: {statuses}")
            print(f"      Created between {first} and {last}")
        
        # Ask for confirmation
        print(f"\n⚠️  This will delete {total_duplicates} duplicate leads")
        print("   The oldest lead in each set will be kept")
        response = input("   Proceed with cleanup? (yes/no): ")
        
        if response.lower() != 'yes':
            print("❌ Cleanup cancelled")
            return False
        
        print("\n🧹 Removing duplicates...")
        
        # Delete duplicate leads (keeping the oldest)
        # First, delete related timeline entries
        delete_timeline_query = text("""
            DELETE FROM lead_timeline_entries 
            WHERE lead_id IN (
                SELECT id FROM (
                    SELECT 
                        id,
                        ROW_NUMBER() OVER (
                            PARTITION BY LOWER(business_name), LOWER(location) 
                            ORDER BY created_at ASC
                        ) as rn
                    FROM leads
                ) ranked
                WHERE rn > 1
            )
        """)
        
        timeline_result = session.execute(delete_timeline_query)
        timeline_deleted = timeline_result.rowcount
        print(f"   Deleted {timeline_deleted} timeline entries")
        
        # Now delete the duplicate leads
        delete_leads_query = text("""
            DELETE FROM leads 
            WHERE id IN (
                SELECT id FROM (
                    SELECT 
                        id,
                        ROW_NUMBER() OVER (
                            PARTITION BY LOWER(business_name), LOWER(location) 
                            ORDER BY created_at ASC
                        ) as rn
                    FROM leads
                ) ranked
                WHERE rn > 1
            )
        """)
        
        leads_result = session.execute(delete_leads_query)
        leads_deleted = leads_result.rowcount
        
        session.commit()
        
        print(f"   ✅ Deleted {leads_deleted} duplicate leads")
        
        # Verify cleanup
        print("\n📊 Verifying cleanup...")
        remaining = session.execute(text("""
            SELECT COUNT(*) FROM (
                SELECT 
                    LOWER(business_name), 
                    LOWER(location), 
                    COUNT(*) as cnt
                FROM leads
                GROUP BY LOWER(business_name), LOWER(location)
                HAVING COUNT(*) > 1
            )
        """)).scalar()
        
        if remaining == 0:
            print("   ✅ All duplicates successfully removed!")
            
            # Show final statistics
            total_leads = session.execute(text("SELECT COUNT(*) FROM leads")).scalar()
            print(f"\n📈 Final statistics:")
            print(f"   Total leads in database: {total_leads}")
            print(f"   Duplicates removed: {leads_deleted}")
            print(f"   Space saved: ~{leads_deleted * 2}KB")
        else:
            print(f"   ⚠️ Warning: {remaining} duplicate sets still remain")
        
        return True
        
    except Exception as e:
        print(f"❌ Error cleaning duplicates: {e}")
        session.rollback()
        return False
    finally:
        session.close()

if __name__ == "__main__":
    success = clean_duplicate_leads()
    sys.exit(0 if success else 1)