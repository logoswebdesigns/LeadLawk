"""
Connection pool management for database connections.
Pattern: Object Pool Pattern - reuses database connections.
Single Responsibility: Connection lifecycle management.
"""

from sqlalchemy import create_engine, event, pool
from sqlalchemy.orm import sessionmaker, Session
from contextlib import contextmanager
from typing import Generator
import logging

from .config import DatabaseConfig

logger = logging.getLogger(__name__)

class ConnectionPool:
    """Manages database connection pooling."""
    
    def __init__(self, config: DatabaseConfig = None):
        """Initialize connection pool with configuration."""
        self.config = config or DatabaseConfig()
        self._engine = None
        self._session_factory = None
        self._setup_engine()
    
    def _setup_engine(self) -> None:
        """Setup SQLAlchemy engine with optimizations."""
        # Create engine with connection pooling
        self._engine = create_engine(
            self.config.database_url,
            poolclass=pool.QueuePool,  # Use QueuePool for better performance
            **self.config.get_engine_kwargs()
        )
        
        # Apply SQLite optimizations on connect
        if "sqlite" in self.config.database_url.lower():
            @event.listens_for(self._engine, "connect")
            def set_sqlite_pragma(dbapi_conn, connection_record):
                self.config.apply_sqlite_optimizations(dbapi_conn)
        
        # Create session factory
        self._session_factory = sessionmaker(
            bind=self._engine,
            autocommit=False,
            autoflush=False,
            expire_on_commit=False  # Prevent unnecessary queries
        )
        
        logger.info(f"Connection pool initialized with size {self.config.pool_size}")
    
    @contextmanager
    def get_session(self) -> Generator[Session, None, None]:
        """Get a database session from the pool."""
        session = self._session_factory()
        try:
            yield session
            session.commit()
        except Exception:
            session.rollback()
            raise
        finally:
            session.close()
    
    def get_engine(self):
        """Get the underlying engine."""
        return self._engine
    
    def dispose(self) -> None:
        """Dispose of the connection pool."""
        if self._engine:
            self._engine.dispose()
            logger.info("Connection pool disposed")
    
    def get_pool_status(self) -> dict:
        """Get current pool status for monitoring."""
        if not self._engine or not self._engine.pool:
            return {}
        
        pool = self._engine.pool
        return {
            "size": pool.size(),
            "checked_in": pool.checkedin(),
            "overflow": pool.overflow(),
            "total": pool.size() + pool.overflow()
        }

# Global connection pool instance
_connection_pool = None

def get_connection_pool() -> ConnectionPool:
    """Get or create the global connection pool."""
    global _connection_pool
    if _connection_pool is None:
        _connection_pool = ConnectionPool()
    return _connection_pool