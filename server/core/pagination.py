"""
Pagination utilities following industry best practices.
Implements Repository Pattern with Specification Pattern for filtering.
"""

from typing import Generic, TypeVar, List, Optional, Dict, Any, Callable
from dataclasses import dataclass
from sqlalchemy.orm import Query, Session
from sqlalchemy import desc, asc, nulls_last, nulls_first
from abc import ABC, abstractmethod
import math

T = TypeVar('T')


@dataclass
class PaginationParams:
    """Standard pagination parameters following REST best practices."""
    page: int = 1
    per_page: int = 20
    
    def __post_init__(self):
        """Validate and sanitize pagination parameters."""
        self.page = max(1, self.page)
        self.per_page = min(100, max(1, self.per_page))  # Cap at 100 for performance
    
    @property
    def offset(self) -> int:
        """Calculate offset for database query."""
        return (self.page - 1) * self.per_page
    
    @property
    def limit(self) -> int:
        """Get limit for database query."""
        return self.per_page


@dataclass
class SortParams:
    """Sorting parameters with null handling."""
    field: str
    ascending: bool = True
    nulls_position: str = "last"  # "first" or "last"
    
    def apply_to_query(self, query: Query, field_map: Dict[str, Any]) -> Query:
        """Apply sorting to a SQLAlchemy query."""
        column = field_map.get(self.field)
        if not column:
            raise ValueError(f"Invalid sort field: {self.field}")
        
        # Apply sort direction
        if self.ascending:
            order_expr = asc(column)
        else:
            order_expr = desc(column)
        
        # Handle nulls
        if self.nulls_position == "first":
            order_expr = nulls_first(order_expr)
        else:
            order_expr = nulls_last(order_expr)
        
        return query.order_by(order_expr)


@dataclass
class PaginatedResponse(Generic[T]):
    """
    Standard paginated response following industry conventions.
    Compatible with frontend frameworks like React Query, Vue Query, etc.
    """
    items: List[T]
    total: int
    page: int
    per_page: int
    total_pages: int
    has_next: bool
    has_prev: bool
    
    @classmethod
    def from_query(
        cls, 
        query: Query, 
        params: PaginationParams,
        transformer: Optional[Callable] = None
    ) -> 'PaginatedResponse[T]':
        """Create paginated response from SQLAlchemy query."""
        total = query.count()
        total_pages = math.ceil(total / params.per_page)
        
        items = query.offset(params.offset).limit(params.limit).all()
        
        if transformer:
            items = [transformer(item) for item in items]
        
        return cls(
            items=items,
            total=total,
            page=params.page,
            per_page=params.per_page,
            total_pages=total_pages,
            has_next=params.page < total_pages,
            has_prev=params.page > 1
        )
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        return {
            "items": self.items,
            "total": self.total,
            "page": self.page,
            "per_page": self.per_page,
            "total_pages": self.total_pages,
            "has_next": self.has_next,
            "has_prev": self.has_prev,
            "links": {
                "self": f"?page={self.page}&per_page={self.per_page}",
                "next": f"?page={self.page + 1}&per_page={self.per_page}" if self.has_next else None,
                "prev": f"?page={self.page - 1}&per_page={self.per_page}" if self.has_prev else None,
                "first": f"?page=1&per_page={self.per_page}",
                "last": f"?page={self.total_pages}&per_page={self.per_page}"
            }
        }


class Specification(ABC):
    """
    Specification Pattern for building complex queries.
    Follows the pattern from Domain-Driven Design.
    """
    
    @abstractmethod
    def apply(self, query: Query) -> Query:
        """Apply this specification to a query."""
        pass
    
    def __and__(self, other: 'Specification') -> 'CompositeSpecification':
        """Combine specifications with AND logic."""
        return CompositeSpecification(self, other, "and")
    
    def __or__(self, other: 'Specification') -> 'CompositeSpecification':
        """Combine specifications with OR logic."""
        return CompositeSpecification(self, other, "or")


class CompositeSpecification(Specification):
    """Composite specification for combining multiple specifications."""
    
    def __init__(self, left: Specification, right: Specification, operator: str):
        self.left = left
        self.right = right
        self.operator = operator
    
    def apply(self, query: Query) -> Query:
        """Apply composite specification."""
        if self.operator == "and":
            return self.right.apply(self.left.apply(query))
        elif self.operator == "or":
            # OR is more complex in SQLAlchemy, would need union
            raise NotImplementedError("OR composition not yet implemented")
        else:
            raise ValueError(f"Unknown operator: {self.operator}")


class PaginationService:
    """
    Service for handling pagination consistently across the application.
    Follows the Service Layer pattern.
    """
    
    @staticmethod
    def paginate(
        query: Query,
        pagination: PaginationParams,
        sort: Optional[SortParams] = None,
        specifications: Optional[List[Specification]] = None,
        field_map: Optional[Dict[str, Any]] = None
    ) -> PaginatedResponse:
        """
        Apply pagination, sorting, and filtering to a query.
        
        Args:
            query: Base SQLAlchemy query
            pagination: Pagination parameters
            sort: Optional sorting parameters
            specifications: Optional list of filter specifications
            field_map: Mapping of field names to database columns
        
        Returns:
            PaginatedResponse with items and metadata
        """
        # Apply specifications (filters)
        if specifications:
            for spec in specifications:
                query = spec.apply(query)
        
        # Apply sorting
        if sort and field_map:
            query = sort.apply_to_query(query, field_map)
        
        # Create paginated response
        return PaginatedResponse.from_query(query, pagination)