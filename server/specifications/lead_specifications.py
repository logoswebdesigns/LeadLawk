"""
Lead-specific specifications following the Specification Pattern.
Each specification encapsulates a single filtering rule.
"""

from typing import Optional, List
from sqlalchemy.orm import Query
from sqlalchemy import or_
from ..core.pagination import Specification
from ..models import Lead, LeadStatus


class StatusSpecification(Specification):
    """Filter leads by status with Flutter enum mapping."""
    
    def __init__(self, status: str):
        self.status = status
    
    def apply(self, query: Query) -> Query:
        """Apply status filter with 'new_' to 'new' mapping."""
        # Map Flutter's 'new_' to database 'new' (new is reserved in Dart)
        db_status = 'new' if self.status == 'new_' else self.status
        return query.filter(Lead.status == db_status)


class IndustrySpecification(Specification):
    """Filter leads by industry."""
    
    def __init__(self, industry: str):
        self.industry = industry
    
    def apply(self, query: Query) -> Query:
        """Apply industry filter."""
        return query.filter(Lead.industry == self.industry)


class LocationSpecification(Specification):
    """Filter leads by location."""
    
    def __init__(self, location: str):
        self.location = location
    
    def apply(self, query: Query) -> Query:
        """Apply location filter."""
        return query.filter(Lead.location == self.location)


class WebsiteSpecification(Specification):
    """Filter leads by website presence."""
    
    def __init__(self, has_website: bool):
        self.has_website = has_website
    
    def apply(self, query: Query) -> Query:
        """Apply website filter."""
        if self.has_website:
            return query.filter(Lead.website_url.isnot(None))
        else:
            return query.filter(Lead.website_url.is_(None))


class SearchSpecification(Specification):
    """Full-text search across multiple fields."""
    
    def __init__(self, search_term: str, fields: Optional[List[str]] = None):
        self.search_term = search_term
        self.fields = fields or ['business_name', 'phone', 'location']
    
    def apply(self, query: Query) -> Query:
        """Apply search filter across specified fields."""
        search_pattern = f"%{self.search_term}%"
        conditions = []
        
        for field in self.fields:
            if hasattr(Lead, field):
                column = getattr(Lead, field)
                conditions.append(column.ilike(search_pattern))
        
        if conditions:
            return query.filter(or_(*conditions))
        return query


class CandidatesOnlySpecification(Specification):
    """Filter for candidate leads only."""
    
    def apply(self, query: Query) -> Query:
        """Apply candidates filter."""
        return query.filter(Lead.is_candidate == True)


class PageSpeedScoreSpecification(Specification):
    """Filter by PageSpeed score ranges."""
    
    def __init__(
        self,
        min_mobile: Optional[int] = None,
        max_mobile: Optional[int] = None,
        min_desktop: Optional[int] = None,
        max_desktop: Optional[int] = None
    ):
        self.min_mobile = min_mobile
        self.max_mobile = max_mobile
        self.min_desktop = min_desktop
        self.max_desktop = max_desktop
    
    def apply(self, query: Query) -> Query:
        """Apply PageSpeed score filters."""
        if self.min_mobile is not None:
            query = query.filter(Lead.pagespeed_mobile_score >= self.min_mobile)
        if self.max_mobile is not None:
            query = query.filter(Lead.pagespeed_mobile_score <= self.max_mobile)
        if self.min_desktop is not None:
            query = query.filter(Lead.pagespeed_desktop_score >= self.min_desktop)
        if self.max_desktop is not None:
            query = query.filter(Lead.pagespeed_desktop_score <= self.max_desktop)
        return query


class PageSpeedTestedSpecification(Specification):
    """Filter by whether PageSpeed has been tested."""
    
    def __init__(self, tested: bool):
        self.tested = tested
    
    def apply(self, query: Query) -> Query:
        """Apply PageSpeed tested filter."""
        if self.tested:
            return query.filter(Lead.pagespeed_tested_at.isnot(None))
        else:
            return query.filter(Lead.pagespeed_tested_at.is_(None))


class RatingRangeSpecification(Specification):
    """Filter by rating range."""
    
    def __init__(self, min_rating: Optional[float] = None, max_rating: Optional[float] = None):
        self.min_rating = min_rating
        self.max_rating = max_rating
    
    def apply(self, query: Query) -> Query:
        """Apply rating range filter."""
        if self.min_rating is not None:
            query = query.filter(Lead.rating >= self.min_rating)
        if self.max_rating is not None:
            query = query.filter(Lead.rating <= self.max_rating)
        return query


class ReviewCountSpecification(Specification):
    """Filter by review count range."""
    
    def __init__(self, min_reviews: Optional[int] = None, max_reviews: Optional[int] = None):
        self.min_reviews = min_reviews
        self.max_reviews = max_reviews
    
    def apply(self, query: Query) -> Query:
        """Apply review count filter."""
        if self.min_reviews is not None:
            query = query.filter(Lead.review_count >= self.min_reviews)
        if self.max_reviews is not None:
            query = query.filter(Lead.review_count <= self.max_reviews)
        return query


class ConversionScoreSpecification(Specification):
    """Filter by conversion score range."""
    
    def __init__(self, min_score: Optional[float] = None, max_score: Optional[float] = None):
        self.min_score = min_score
        self.max_score = max_score
    
    def apply(self, query: Query) -> Query:
        """Apply conversion score filter."""
        if self.min_score is not None:
            query = query.filter(Lead.conversion_score >= self.min_score)
        if self.max_score is not None:
            query = query.filter(Lead.conversion_score <= self.max_score)
        return query


class DateRangeSpecification(Specification):
    """Filter by date range."""
    
    def __init__(self, field: str, start_date=None, end_date=None):
        self.field = field
        self.start_date = start_date
        self.end_date = end_date
    
    def apply(self, query: Query) -> Query:
        """Apply date range filter."""
        if hasattr(Lead, self.field):
            column = getattr(Lead, self.field)
            if self.start_date:
                query = query.filter(column >= self.start_date)
            if self.end_date:
                query = query.filter(column <= self.end_date)
        return query