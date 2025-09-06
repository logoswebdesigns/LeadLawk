"""
Database index definitions and management.
Pattern: Index Management - optimizes query performance.
Single Responsibility: Database index creation and maintenance.
"""

from sqlalchemy import Index, text
from typing import List, Dict, Any
import logging

logger = logging.getLogger(__name__)

class IndexManager:
    """Manages database indices for query optimization."""
    
    @staticmethod
    def get_index_definitions() -> List[Dict[str, Any]]:
        """Get all index definitions for the database."""
        return [
            # Lead indices
            {
                'name': 'idx_leads_status_user',
                'table': 'leads',
                'columns': ['status', 'user_id'],
                'description': 'Optimize lead filtering by status and user'
            },
            {
                'name': 'idx_leads_phone',
                'table': 'leads',
                'columns': ['phone'],
                'unique': True,
                'description': 'Prevent duplicate leads by phone'
            },
            {
                'name': 'idx_leads_conversion_score',
                'table': 'leads',
                'columns': ['conversion_score'],
                'where': 'conversion_score IS NOT NULL',
                'description': 'Optimize queries by conversion score'
            },
            {
                'name': 'idx_leads_follow_up',
                'table': 'leads',
                'columns': ['follow_up_date', 'status'],
                'where': 'follow_up_date IS NOT NULL',
                'description': 'Optimize follow-up queries'
            },
            {
                'name': 'idx_leads_created_at',
                'table': 'leads',
                'columns': ['created_at'],
                'description': 'Optimize time-based queries'
            },
            {
                'name': 'idx_leads_location_industry',
                'table': 'leads',
                'columns': ['location', 'industry'],
                'description': 'Optimize location and industry filtering'
            },
            
            # Timeline entries indices
            {
                'name': 'idx_timeline_lead_created',
                'table': 'lead_timeline_entries',
                'columns': ['lead_id', 'created_at'],
                'description': 'Optimize timeline queries'
            },
            {
                'name': 'idx_timeline_type',
                'table': 'lead_timeline_entries',
                'columns': ['type', 'created_at'],
                'description': 'Optimize timeline filtering by type'
            },
            {
                'name': 'idx_timeline_follow_up',
                'table': 'lead_timeline_entries',
                'columns': ['follow_up_date', 'is_completed'],
                'where': 'follow_up_date IS NOT NULL',
                'description': 'Optimize follow-up timeline queries'
            },
            
            # Call log indices
            {
                'name': 'idx_call_logs_lead',
                'table': 'call_logs',
                'columns': ['lead_id', 'called_at'],
                'description': 'Optimize call history queries'
            },
            {
                'name': 'idx_call_logs_user',
                'table': 'call_logs',
                'columns': ['created_by_id', 'called_at'],
                'description': 'Optimize user call history'
            },
            
            # User indices
            {
                'name': 'idx_users_email',
                'table': 'users',
                'columns': ['email'],
                'unique': True,
                'description': 'Unique email constraint and lookup'
            },
            
            # Sales pitch indices
            {
                'name': 'idx_sales_pitch_active',
                'table': 'sales_pitches',
                'columns': ['is_active', 'conversion_rate'],
                'description': 'Optimize active pitch queries'
            },
            
            # Email template indices
            {
                'name': 'idx_email_templates_user',
                'table': 'email_templates',
                'columns': ['user_id', 'is_active'],
                'description': 'Optimize template queries by user'
            }
        ]
    
    @staticmethod
    def create_indices(engine) -> List[str]:
        """Create all database indices."""
        created = []
        indices = IndexManager.get_index_definitions()
        
        with engine.connect() as conn:
            for index_def in indices:
                try:
                    # Build CREATE INDEX statement
                    columns = ', '.join(index_def['columns'])
                    unique = 'UNIQUE' if index_def.get('unique', False) else ''
                    where = f"WHERE {index_def.get('where')}" if 'where' in index_def else ''
                    
                    sql = f"""
                    CREATE {unique} INDEX IF NOT EXISTS {index_def['name']}
                    ON {index_def['table']} ({columns})
                    {where}
                    """
                    
                    conn.execute(text(sql))
                    created.append(index_def['name'])
                    logger.info(f"Created index: {index_def['name']}")
                    
                except Exception as e:
                    logger.error(f"Failed to create index {index_def['name']}: {e}")
        
        return created
    
    @staticmethod
    def analyze_tables(engine) -> None:
        """Run ANALYZE on all tables to update statistics."""
        tables = [
            'leads', 'users', 'call_logs', 'lead_timeline_entries',
            'sales_pitches', 'email_templates', 'conversion_model'
        ]
        
        with engine.connect() as conn:
            for table in tables:
                try:
                    # SQLite specific ANALYZE
                    conn.execute(text(f"ANALYZE {table}"))
                    logger.info(f"Analyzed table: {table}")
                except Exception as e:
                    logger.error(f"Failed to analyze table {table}: {e}")
    
    @staticmethod
    def get_index_usage(engine) -> Dict[str, Any]:
        """Get index usage statistics (SQLite specific)."""
        stats = {}
        
        with engine.connect() as conn:
            try:
                # Get SQLite statistics
                result = conn.execute(text("SELECT * FROM sqlite_stat1"))
                for row in result:
                    stats[row[1]] = {
                        'table': row[0],
                        'statistics': row[2]
                    }
            except Exception as e:
                logger.error(f"Failed to get index statistics: {e}")
        
        return stats
    
    @staticmethod
    def optimize_database(engine) -> None:
        """Run database optimization commands."""
        with engine.connect() as conn:
            try:
                # SQLite specific optimizations
                conn.execute(text("PRAGMA optimize"))
                conn.execute(text("VACUUM"))
                conn.execute(text("REINDEX"))
                logger.info("Database optimization completed")
            except Exception as e:
                logger.error(f"Database optimization failed: {e}")