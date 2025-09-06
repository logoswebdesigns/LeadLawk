"""
Query builder for optimized database queries.
Pattern: Builder Pattern - constructs complex queries.
Single Responsibility: Query construction and optimization.
"""

from typing import List, Optional, Any, Type, Dict
from sqlalchemy.orm import Session, joinedload, selectinload, Query
from sqlalchemy import and_, or_, desc, asc, func
from datetime import datetime, timedelta

class QueryBuilder:
    """Builds optimized database queries with eager loading."""
    
    def __init__(self, session: Session, model: Type):
        """Initialize query builder with session and model."""
        self.session = session
        self.model = model
        self.query = session.query(model)
        self._filters = []
        self._joins = []
        self._eager_loads = []
        self._order_by = []
        self._limit = None
        self._offset = None
    
    def filter(self, *conditions) -> 'QueryBuilder':
        """Add filter conditions."""
        self._filters.extend(conditions)
        return self
    
    def filter_by(self, **kwargs) -> 'QueryBuilder':
        """Add equality filters."""
        for key, value in kwargs.items():
            self._filters.append(getattr(self.model, key) == value)
        return self
    
    def join(self, *relationships) -> 'QueryBuilder':
        """Add joins to the query."""
        self._joins.extend(relationships)
        return self
    
    def eager_load(self, *relationships) -> 'QueryBuilder':
        """Add eager loading for relationships to prevent N+1."""
        for rel in relationships:
            # Use selectinload for collections, joinedload for single relations
            self._eager_loads.append(selectinload(rel))
        return self
    
    def order_by(self, column, direction='asc') -> 'QueryBuilder':
        """Add ordering to the query."""
        if direction.lower() == 'desc':
            self._order_by.append(desc(column))
        else:
            self._order_by.append(asc(column))
        return self
    
    def paginate(self, page: int = 1, per_page: int = 20) -> 'QueryBuilder':
        """Add pagination to the query."""
        self._limit = per_page
        self._offset = (page - 1) * per_page
        return self
    
    def build(self) -> Query:
        """Build the final query with all optimizations."""
        query = self.query
        
        # Apply eager loading first
        for eager_load in self._eager_loads:
            query = query.options(eager_load)
        
        # Apply joins
        for join in self._joins:
            query = query.join(join)
        
        # Apply filters
        if self._filters:
            query = query.filter(and_(*self._filters))
        
        # Apply ordering
        for order in self._order_by:
            query = query.order_by(order)
        
        # Apply pagination
        if self._limit:
            query = query.limit(self._limit)
        if self._offset:
            query = query.offset(self._offset)
        
        return query
    
    def all(self) -> List:
        """Execute query and return all results."""
        return self.build().all()
    
    def first(self) -> Optional[Any]:
        """Execute query and return first result."""
        return self.build().first()
    
    def count(self) -> int:
        """Get count of results."""
        # Remove ordering and pagination for count
        query = self.session.query(func.count(self.model.id))
        
        # Apply joins and filters
        for join in self._joins:
            query = query.join(join)
        if self._filters:
            query = query.filter(and_(*self._filters))
        
        return query.scalar()
    
    def exists(self) -> bool:
        """Check if any results exist."""
        return self.session.query(self.build().exists()).scalar()

class LeadQueryBuilder(QueryBuilder):
    """Specialized query builder for Lead model with common optimizations."""
    
    def with_timeline(self) -> 'LeadQueryBuilder':
        """Eager load timeline entries."""
        from models import LeadTimelineEntry
        return self.eager_load('timeline_entries')
    
    def with_call_logs(self) -> 'LeadQueryBuilder':
        """Eager load call logs."""
        return self.eager_load('call_logs')
    
    def with_user(self) -> 'LeadQueryBuilder':
        """Eager load user relationship."""
        return self.eager_load('user')
    
    def with_all_relationships(self) -> 'LeadQueryBuilder':
        """Eager load all relationships to prevent N+1."""
        return self.with_timeline().with_call_logs().with_user()
    
    def active_leads(self) -> 'LeadQueryBuilder':
        """Filter for active leads only."""
        from models import LeadStatus
        return self.filter(
            ~self.model.status.in_([
                LeadStatus.converted,
                LeadStatus.doNotCall,
                LeadStatus.didNotConvert
            ])
        )
    
    def needs_follow_up(self) -> 'LeadQueryBuilder':
        """Filter for leads needing follow-up."""
        today = datetime.utcnow().date()
        return self.filter(
            self.model.follow_up_date <= today,
            self.model.follow_up_date.isnot(None)
        )
    
    def by_conversion_score(self, min_score: float = 0.5) -> 'LeadQueryBuilder':
        """Filter by minimum conversion score."""
        return self.filter(
            self.model.conversion_score >= min_score
        ).order_by(self.model.conversion_score, 'desc')