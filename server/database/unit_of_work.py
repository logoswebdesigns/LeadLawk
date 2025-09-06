"""
Unit of Work pattern for database transactions.
Pattern: Unit of Work Pattern - manages database transactions.
Single Responsibility: Transaction boundary management.
"""

from sqlalchemy.orm import Session
from contextlib import contextmanager
from typing import Optional, Any, Dict
import logging
from datetime import datetime

from .connection_pool import get_connection_pool

logger = logging.getLogger(__name__)

class UnitOfWork:
    """Manages database transactions as a unit of work."""
    
    def __init__(self, session: Optional[Session] = None):
        """Initialize unit of work with optional session."""
        self._session = session
        self._pool = get_connection_pool()
        self._is_active = False
        self._changes = []
        self._start_time = None
    
    def __enter__(self) -> 'UnitOfWork':
        """Enter transaction context."""
        if not self._session:
            self._session = self._pool._session_factory()
        self._is_active = True
        self._start_time = datetime.utcnow()
        logger.debug("Unit of Work started")
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Exit transaction context with automatic commit/rollback."""
        if exc_type:
            self.rollback()
            logger.error(f"Unit of Work rolled back due to: {exc_val}")
        else:
            try:
                self.commit()
                duration = (datetime.utcnow() - self._start_time).total_seconds()
                logger.debug(f"Unit of Work committed in {duration:.3f}s")
            except Exception as e:
                self.rollback()
                logger.error(f"Unit of Work rollback on commit error: {e}")
                raise
        finally:
            self.close()
    
    @property
    def session(self) -> Session:
        """Get the current session."""
        if not self._session:
            raise RuntimeError("Unit of Work not active")
        return self._session
    
    def add(self, entity: Any) -> None:
        """Add entity to the session."""
        self.session.add(entity)
        self._track_change('add', entity)
    
    def add_all(self, entities: list) -> None:
        """Add multiple entities to the session."""
        self.session.add_all(entities)
        for entity in entities:
            self._track_change('add', entity)
    
    def delete(self, entity: Any) -> None:
        """Delete entity from the session."""
        self.session.delete(entity)
        self._track_change('delete', entity)
    
    def commit(self) -> None:
        """Commit the transaction."""
        if self._session:
            self._session.commit()
            self._changes.clear()
    
    def rollback(self) -> None:
        """Rollback the transaction."""
        if self._session:
            self._session.rollback()
            self._changes.clear()
    
    def close(self) -> None:
        """Close the session."""
        if self._session:
            self._session.close()
            self._session = None
        self._is_active = False
    
    def flush(self) -> None:
        """Flush pending changes without committing."""
        if self._session:
            self._session.flush()
    
    def refresh(self, entity: Any) -> None:
        """Refresh entity from database."""
        if self._session:
            self._session.refresh(entity)
    
    def _track_change(self, operation: str, entity: Any) -> None:
        """Track changes for auditing."""
        self._changes.append({
            'operation': operation,
            'entity': entity.__class__.__name__,
            'id': getattr(entity, 'id', None),
            'timestamp': datetime.utcnow()
        })
    
    def get_pending_changes(self) -> list:
        """Get list of pending changes."""
        return self._changes.copy()

class TransactionalService:
    """Base class for services that use Unit of Work pattern."""
    
    def __init__(self):
        """Initialize transactional service."""
        self._pool = get_connection_pool()
    
    @contextmanager
    def unit_of_work(self) -> UnitOfWork:
        """Create a unit of work context."""
        uow = UnitOfWork()
        try:
            with uow:
                yield uow
        except Exception:
            raise
    
    def execute_in_transaction(self, func, *args, **kwargs):
        """Execute function within a transaction."""
        with self.unit_of_work() as uow:
            return func(uow, *args, **kwargs)

class BatchProcessor:
    """Process database operations in batches for performance."""
    
    def __init__(self, batch_size: int = 100):
        """Initialize batch processor."""
        self.batch_size = batch_size
        self._pool = get_connection_pool()
    
    def process_batch(self, items: list, processor_func) -> Dict[str, Any]:
        """Process items in batches within transactions."""
        total = len(items)
        processed = 0
        errors = []
        
        for i in range(0, total, self.batch_size):
            batch = items[i:i + self.batch_size]
            
            with UnitOfWork() as uow:
                try:
                    for item in batch:
                        processor_func(uow, item)
                    processed += len(batch)
                    logger.info(f"Processed batch {i//self.batch_size + 1}: "
                              f"{processed}/{total} items")
                except Exception as e:
                    errors.append({
                        'batch': i // self.batch_size + 1,
                        'error': str(e),
                        'items': batch
                    })
                    logger.error(f"Batch {i//self.batch_size + 1} failed: {e}")
        
        return {
            'total': total,
            'processed': processed,
            'failed': total - processed,
            'errors': errors
        }