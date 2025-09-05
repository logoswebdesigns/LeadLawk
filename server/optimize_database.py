#!/usr/bin/env python3
"""
Database optimization script to add indexes and improve query performance.
Run this to optimize the existing database.
"""

import sqlite3
import time

def add_indexes(db_path="db/leadloq.db"):
    """Add missing indexes to improve query performance"""
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # List of indexes to create
    indexes = [
        # Core indexes for filtering and sorting
        ("idx_leads_status", "leads", "(status)"),
        ("idx_leads_created_at", "leads", "(created_at DESC)"),
        ("idx_leads_is_candidate", "leads", "(is_candidate)"),
        ("idx_leads_location", "leads", "(location)"),
        ("idx_leads_industry", "leads", "(industry)"),
        
        # Composite indexes for common query patterns
        ("idx_leads_status_created", "leads", "(status, created_at DESC)"),
        ("idx_leads_candidate_created", "leads", "(is_candidate, created_at DESC)"),
        ("idx_leads_status_candidate", "leads", "(status, is_candidate)"),
        
        # PageSpeed related indexes
        ("idx_leads_pagespeed_mobile", "leads", "(pagespeed_mobile_score)"),
        ("idx_leads_conversion_score", "leads", "(conversion_score DESC)"),
        
        # Timeline indexes
        ("idx_timeline_lead_id", "lead_timeline_entries", "(lead_id, created_at DESC)"),
        ("idx_timeline_type", "lead_timeline_entries", "(entry_type)"),
        
        # Call log indexes
        ("idx_calls_lead_id", "call_logs", "(lead_id)"),
        ("idx_calls_date", "call_logs", "(called_at DESC)"),
    ]
    
    print("Starting database optimization...")
    print(f"Database: {db_path}")
    print("-" * 50)
    
    for index_name, table, columns in indexes:
        try:
            # Check if index already exists
            cursor.execute("""
                SELECT name FROM sqlite_master 
                WHERE type='index' AND name=?
            """, (index_name,))
            
            if cursor.fetchone():
                print(f"✓ Index {index_name} already exists")
            else:
                # Create the index
                start_time = time.time()
                cursor.execute(f"CREATE INDEX {index_name} ON {table} {columns}")
                elapsed = time.time() - start_time
                print(f"✓ Created index {index_name} ({elapsed:.2f}s)")
        except Exception as e:
            print(f"✗ Error creating index {index_name}: {e}")
    
    # Analyze the database to update statistics
    print("\nUpdating database statistics...")
    cursor.execute("ANALYZE")
    
    # Get some performance stats
    cursor.execute("SELECT COUNT(*) FROM leads")
    total_leads = cursor.fetchone()[0]
    
    cursor.execute("SELECT COUNT(DISTINCT status) FROM leads")
    status_count = cursor.fetchone()[0]
    
    print(f"\nDatabase Statistics:")
    print(f"  Total leads: {total_leads:,}")
    print(f"  Unique statuses: {status_count}")
    
    # Show index usage
    print("\nIndexes on leads table:")
    cursor.execute("""
        SELECT name, sql FROM sqlite_master 
        WHERE type='index' AND tbl_name='leads'
        ORDER BY name
    """)
    
    for name, sql in cursor.fetchall():
        if sql:  # Skip auto-indexes
            print(f"  - {name}")
    
    conn.commit()
    conn.close()
    
    print("\n✓ Database optimization complete!")
    
    return True

if __name__ == "__main__":
    add_indexes()