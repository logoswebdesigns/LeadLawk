#!/usr/bin/env python3
"""
Cleanup duplicate leads based on business name.
Keeps the oldest (first created) lead and removes duplicates.
"""

from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from models import Lead, LeadTimelineEntry, CallLog
from datetime import datetime
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def cleanup_duplicates():
    """Remove duplicate leads keeping only the oldest one for each business name"""
    
    engine = create_engine('sqlite:///db/leadloq.db')
    Session = sessionmaker(bind=engine)
    session = Session()
    
    try:
        # First, let's identify duplicates
        logger.info("🔍 Identifying duplicate leads by business name...")
        
        # Find all business names that have duplicates
        duplicate_query = text("""
            SELECT business_name, COUNT(*) as count, GROUP_CONCAT(id) as lead_ids
            FROM leads
            GROUP BY business_name
            HAVING COUNT(*) > 1
            ORDER BY count DESC
        """)
        
        duplicates = session.execute(duplicate_query).fetchall()
        
        if not duplicates:
            logger.info("✅ No duplicate leads found!")
            return
        
        logger.info(f"Found {len(duplicates)} business names with duplicates")
        
        total_duplicates_to_remove = 0
        leads_to_delete = []
        
        for business_name, count, lead_ids_str in duplicates:
            lead_ids = lead_ids_str.split(',')
            logger.info(f"  '{business_name}': {count} instances")
            
            # Get the oldest lead (keep this one)
            oldest_query = text("""
                SELECT id, created_at 
                FROM leads 
                WHERE business_name = :name
                ORDER BY created_at ASC
                LIMIT 1
            """)
            
            oldest = session.execute(oldest_query, {'name': business_name}).fetchone()
            keep_id = oldest[0]
            
            # Mark others for deletion
            for lead_id in lead_ids:
                if lead_id != keep_id:
                    leads_to_delete.append(lead_id)
                    total_duplicates_to_remove += 1
        
        logger.info(f"\n📊 Summary:")
        logger.info(f"  - Total duplicate leads to remove: {total_duplicates_to_remove}")
        logger.info(f"  - Unique business names affected: {len(duplicates)}")
        
        if total_duplicates_to_remove == 0:
            logger.info("No duplicates to remove.")
            return
        
        # Confirm before deletion
        logger.info("\n⚠️  About to delete duplicate leads...")
        
        # Delete related records first (timeline entries, call logs)
        for lead_id in leads_to_delete:
            # Delete timeline entries
            timeline_delete = text("""
                DELETE FROM lead_timeline_entries 
                WHERE lead_id = :lead_id
            """)
            result = session.execute(timeline_delete, {'lead_id': lead_id})
            logger.debug(f"  Deleted {result.rowcount} timeline entries for lead {lead_id}")
            
            # Delete call logs
            call_log_delete = text("""
                DELETE FROM call_logs 
                WHERE lead_id = :lead_id
            """)
            result = session.execute(call_log_delete, {'lead_id': lead_id})
            logger.debug(f"  Deleted {result.rowcount} call logs for lead {lead_id}")
        
        # Now delete the duplicate leads
        # Delete them one by one to avoid parameter binding issues
        deleted_count = 0
        for lead_id in leads_to_delete:
            lead_delete_query = text("""
                DELETE FROM leads 
                WHERE id = :lead_id
            """)
            result = session.execute(lead_delete_query, {'lead_id': lead_id})
            deleted_count += result.rowcount
            
            if deleted_count % 100 == 0:
                logger.info(f"  Deleted {deleted_count}/{len(leads_to_delete)} duplicate leads...")
                session.commit()  # Commit in batches to avoid large transactions
        
        session.commit()
        
        logger.info(f"\n✅ Successfully deleted {deleted_count} duplicate leads!")
        
        # Verify the cleanup
        verify_query = text("""
            SELECT COUNT(*) as total_leads,
                   COUNT(DISTINCT business_name) as unique_businesses
            FROM leads
        """)
        
        verify = session.execute(verify_query).fetchone()
        logger.info(f"\n📊 Final Statistics:")
        logger.info(f"  - Total leads remaining: {verify[0]}")
        logger.info(f"  - Unique business names: {verify[1]}")
        
    except Exception as e:
        logger.error(f"❌ Failed to cleanup duplicates: {e}")
        session.rollback()
        raise
    finally:
        session.close()

if __name__ == "__main__":
    logger.info("🧹 Starting duplicate leads cleanup...")
    logger.info(f"Timestamp: {datetime.now()}")
    cleanup_duplicates()
    logger.info("\n✨ Cleanup complete!")