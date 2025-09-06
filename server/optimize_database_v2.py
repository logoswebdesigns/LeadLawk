#!/usr/bin/env python3
"""
Apply database optimizations including indices, connection pooling, and monitoring.
Pattern: Database Optimization Script.
"""

import sys
import logging
from pathlib import Path

# Add parent directory to path
sys.path.append(str(Path(__file__).parent))

from database.config import DatabaseConfig
from database.connection_pool import ConnectionPool
from database.indices import IndexManager
from database.query_monitor import QueryMonitor
from sqlalchemy import create_engine, text

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def apply_optimizations():
    """Apply all database optimizations."""
    logger.info("Starting database optimization...")
    
    # 1. Initialize configuration
    config = DatabaseConfig()
    
    # 2. Create optimized engine
    engine = create_engine(
        config.database_url,
        **config.get_engine_kwargs()
    )
    
    # 3. Apply SQLite-specific optimizations
    if "sqlite" in config.database_url.lower():
        with engine.connect() as conn:
            config.apply_sqlite_optimizations(conn)
            logger.info("Applied SQLite optimizations")
    
    # 4. Create indices
    logger.info("Creating database indices...")
    created_indices = IndexManager.create_indices(engine)
    logger.info(f"Created {len(created_indices)} indices")
    
    # 5. Analyze tables
    logger.info("Analyzing tables...")
    IndexManager.analyze_tables(engine)
    
    # 6. Run optimization commands
    logger.info("Running database optimization...")
    IndexManager.optimize_database(engine)
    
    # 7. Enable query monitoring
    monitor = QueryMonitor(slow_query_threshold=0.1)  # 100ms threshold
    monitor.enable(engine)
    logger.info("Query monitoring enabled")
    
    # 8. Test connection pool
    pool = ConnectionPool(config)
    status = pool.get_pool_status()
    logger.info(f"Connection pool status: {status}")
    
    # 9. Verify optimizations
    with engine.connect() as conn:
        # Check pragma settings
        pragmas = [
            'journal_mode', 'cache_size', 'synchronous',
            'temp_store', 'mmap_size', 'page_size'
        ]
        
        logger.info("Current SQLite settings:")
        for pragma in pragmas:
            result = conn.execute(text(f"PRAGMA {pragma}"))
            value = result.scalar()
            logger.info(f"  {pragma}: {value}")
        
        # Check index count
        result = conn.execute(text(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='index'"
        ))
        index_count = result.scalar()
        logger.info(f"Total indices: {index_count}")
    
    logger.info("Database optimization completed successfully!")
    
    # Export initial performance report
    monitor.export_report("database_performance_report.json")
    
    return True

if __name__ == "__main__":
    try:
        apply_optimizations()
    except Exception as e:
        logger.error(f"Optimization failed: {e}")
        sys.exit(1)