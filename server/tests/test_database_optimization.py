"""
Tests for database optimization components.
Pattern: Unit Testing - verifies optimization functionality.
"""

import unittest
import tempfile
import os
from datetime import datetime, timedelta

from database.config import DatabaseConfig
from database.connection_pool import ConnectionPool
from database.query_builder import QueryBuilder, LeadQueryBuilder
from database.unit_of_work import UnitOfWork, BatchProcessor
from database.query_monitor import QueryMonitor
from database.indices import IndexManager
from models import Base, Lead, LeadStatus, User
from sqlalchemy import create_engine

class TestDatabaseOptimization(unittest.TestCase):
    """Test database optimization components."""
    
    @classmethod
    def setUpClass(cls):
        """Set up test database."""
        # Create temporary database
        cls.db_fd, cls.db_path = tempfile.mkstemp(suffix='.db')
        cls.db_url = f"sqlite:///{cls.db_path}"
        
        # Create engine and tables
        cls.engine = create_engine(cls.db_url)
        Base.metadata.create_all(cls.engine)
    
    @classmethod
    def tearDownClass(cls):
        """Clean up test database."""
        cls.engine.dispose()
        os.close(cls.db_fd)
        os.unlink(cls.db_path)
    
    def test_connection_pool(self):
        """Test connection pool functionality."""
        config = DatabaseConfig()
        config.database_url = self.db_url
        pool = ConnectionPool(config)
        
        # Test getting session
        with pool.get_session() as session:
            self.assertIsNotNone(session)
            
            # Test basic query
            result = session.execute("SELECT 1").scalar()
            self.assertEqual(result, 1)
        
        # Check pool status
        status = pool.get_pool_status()
        self.assertIn('size', status)
        self.assertIn('checked_in', status)
        
        pool.dispose()
    
    def test_query_builder(self):
        """Test query builder functionality."""
        config = DatabaseConfig()
        config.database_url = self.db_url
        pool = ConnectionPool(config)
        
        with pool.get_session() as session:
            # Create test data
            user = User(
                id="test_user",
                email="test@example.com",
                hashed_password="hash",
                full_name="Test User"
            )
            session.add(user)
            
            leads = [
                Lead(
                    id=f"lead_{i}",
                    user_id="test_user",
                    business_name=f"Business {i}",
                    phone=f"555-000{i}",
                    industry="Tech",
                    location="Test City",
                    status=LeadStatus.new if i % 2 == 0 else LeadStatus.called,
                    conversion_score=i * 0.1
                )
                for i in range(10)
            ]
            session.add_all(leads)
            session.commit()
            
            # Test query builder
            builder = LeadQueryBuilder(session, Lead)
            
            # Test filtering
            results = builder.filter_by(user_id="test_user").all()
            self.assertEqual(len(results), 10)
            
            # Test pagination
            builder = LeadQueryBuilder(session, Lead)
            results = builder.paginate(1, 5).all()
            self.assertEqual(len(results), 5)
            
            # Test ordering
            builder = LeadQueryBuilder(session, Lead)
            results = builder.order_by(Lead.conversion_score, 'desc').all()
            self.assertGreaterEqual(
                results[0].conversion_score,
                results[-1].conversion_score
            )
            
            # Test eager loading (no N+1)
            builder = LeadQueryBuilder(session, Lead)
            results = builder.with_all_relationships().all()
            # Accessing relationships shouldn't trigger new queries
            for lead in results:
                _ = lead.timeline_entries
                _ = lead.call_logs
        
        pool.dispose()
    
    def test_unit_of_work(self):
        """Test unit of work pattern."""
        config = DatabaseConfig()
        config.database_url = self.db_url
        
        # Test successful transaction
        with UnitOfWork() as uow:
            user = User(
                id="uow_user",
                email="uow@example.com",
                hashed_password="hash",
                full_name="UOW User"
            )
            uow.add(user)
            
            lead = Lead(
                id="uow_lead",
                user_id="uow_user",
                business_name="UOW Business",
                phone="555-0099",
                industry="Tech",
                location="Test City"
            )
            uow.add(lead)
            
            # Check pending changes
            changes = uow.get_pending_changes()
            self.assertEqual(len(changes), 2)
        
        # Verify data was committed
        with UnitOfWork() as uow:
            lead = uow.session.query(Lead).filter_by(id="uow_lead").first()
            self.assertIsNotNone(lead)
            self.assertEqual(lead.business_name, "UOW Business")
    
    def test_batch_processor(self):
        """Test batch processing."""
        processor = BatchProcessor(batch_size=3)
        
        # Create test items
        items = [f"item_{i}" for i in range(10)]
        processed_items = []
        
        def process_item(uow, item):
            """Process single item."""
            processed_items.append(item)
        
        # Process batch
        result = processor.process_batch(items, process_item)
        
        self.assertEqual(result['total'], 10)
        self.assertEqual(result['processed'], 10)
        self.assertEqual(len(processed_items), 10)
    
    def test_query_monitor(self):
        """Test query performance monitoring."""
        monitor = QueryMonitor(slow_query_threshold=0.001)  # 1ms threshold
        monitor.enable(self.engine)
        
        # Execute some queries
        with self.engine.connect() as conn:
            conn.execute("SELECT 1")
            conn.execute("SELECT * FROM leads WHERE id = 'test'")
            conn.execute("SELECT COUNT(*) FROM leads")
        
        # Check statistics
        stats = monitor.get_statistics()
        self.assertGreater(stats['total_queries'], 0)
        self.assertGreater(stats['unique_queries'], 0)
    
    def test_index_manager(self):
        """Test index creation and management."""
        # Get index definitions
        indices = IndexManager.get_index_definitions()
        self.assertGreater(len(indices), 0)
        
        # Create indices
        created = IndexManager.create_indices(self.engine)
        self.assertIsInstance(created, list)
        
        # Analyze tables
        IndexManager.analyze_tables(self.engine)
        
        # Check index usage
        usage = IndexManager.get_index_usage(self.engine)
        self.assertIsInstance(usage, dict)

if __name__ == "__main__":
    unittest.main()