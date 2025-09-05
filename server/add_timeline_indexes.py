#!/usr/bin/env python3
"""
Add database indexes for optimized timeline queries.
This migration adds indexes to improve performance of today's calls and timeline filtering.
"""

from sqlalchemy import create_engine, text, Index
from sqlalchemy.orm import sessionmaker
from models import Base, LeadTimelineEntry
import logging
from datetime import datetime

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def add_indexes():
    """Add performance-critical indexes for timeline queries"""
    
    engine = create_engine('sqlite:///db/leadloq.db')
    Session = sessionmaker(bind=engine)
    session = Session()
    
    try:
        # Create composite indexes for the most common query patterns
        indexes = [
            # Primary index for timeline type and date filtering
            """CREATE INDEX IF NOT EXISTS idx_timeline_type_created 
               ON lead_timeline_entries(type, created_at DESC)""",
            
            # Index for status change queries with date filtering
            """CREATE INDEX IF NOT EXISTS idx_timeline_status_created 
               ON lead_timeline_entries(new_status, created_at DESC) 
               WHERE type = 'status_change'""",
            
            # Index for lead-specific timeline queries
            """CREATE INDEX IF NOT EXISTS idx_timeline_lead_created 
               ON lead_timeline_entries(lead_id, created_at DESC)""",
            
            # Covering index for phone call queries
            """CREATE INDEX IF NOT EXISTS idx_timeline_phonecall 
               ON lead_timeline_entries(created_at DESC, lead_id) 
               WHERE type = 'phone_call'""",
            
            # Index for efficient DISTINCT lead_id queries
            """CREATE INDEX IF NOT EXISTS idx_timeline_lead_type 
               ON lead_timeline_entries(lead_id, type)""",
        ]
        
        for idx_sql in indexes:
            logger.info(f"Creating index: {idx_sql[:50]}...")
            session.execute(text(idx_sql))
            session.commit()
        
        # Analyze the database to update statistics for query planner
        logger.info("Analyzing database for query optimization...")
        session.execute(text("ANALYZE"))
        session.commit()
        
        # Verify indexes were created
        result = session.execute(text("""
            SELECT name, sql 
            FROM sqlite_master 
            WHERE type = 'index' 
            AND tbl_name = 'lead_timeline_entries'
        """))
        
        indexes_created = result.fetchall()
        logger.info(f"\nCreated {len(indexes_created)} indexes on lead_timeline_entries:")
        for name, sql in indexes_created:
            if sql:  # Skip auto-indexes
                logger.info(f"  - {name}")
        
        logger.info("\n✅ Indexes successfully created!")
        
        # Test query performance
        test_performance(session)
        
    except Exception as e:
        logger.error(f"Failed to create indexes: {e}")
        session.rollback()
        raise
    finally:
        session.close()

def test_performance(session):
    """Test query performance with new indexes"""
    import time
    
    logger.info("\n🧪 Testing query performance with new indexes...")
    
    # Test today's calls query
    query = text("""
        SELECT COUNT(DISTINCT lead_id) as count
        FROM (
            SELECT lead_id
            FROM lead_timeline_entries
            WHERE type = 'phone_call'
              AND created_at >= date('now', 'start of day')
              AND created_at <= date('now', '+1 day', 'start of day')
            
            UNION
            
            SELECT lead_id
            FROM lead_timeline_entries
            WHERE type = 'status_change'
              AND new_status IN ('called', 'interested', 'converted')
              AND created_at >= date('now', 'start of day')
              AND created_at <= date('now', '+1 day', 'start of day')
        ) as today_calls
    """)
    
    start = time.time()
    result = session.execute(query)
    count = result.scalar()
    elapsed = (time.time() - start) * 1000
    
    logger.info(f"  Today's calls query: {count} results in {elapsed:.2f}ms")
    
    # Test EXPLAIN QUERY PLAN
    explain = session.execute(text(f"EXPLAIN QUERY PLAN {query.text}"))
    logger.info("  Query plan:")
    for row in explain:
        logger.info(f"    {row}")
    
    logger.info("\n📊 Performance Summary:")
    logger.info(f"  - Query execution time: {elapsed:.2f}ms")
    logger.info(f"  - Expected performance: <10ms for typical dataset")
    logger.info(f"  - Scalability: O(log n) with index vs O(n) without")

if __name__ == "__main__":
    logger.info("🚀 Starting database optimization for timeline queries...")
    logger.info(f"Timestamp: {datetime.now()}")
    add_indexes()