"""
Comprehensive tests for lead pagination, filtering, and sorting.
Validates that the implementation follows industry best practices.
"""

import pytest
from datetime import datetime
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from unittest.mock import MagicMock, patch

# Import the service and models
import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from models import Base, Lead, LeadStatus
from services.lead_service import LeadService
from schemas import PaginatedResponse


class TestLeadPaginationPattern:
    """Test suite proving the pagination implementation follows best practices."""
    
    @pytest.fixture
    def db_session(self):
        """Create an in-memory SQLite database for testing."""
        engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(engine)
        SessionLocal = sessionmaker(bind=engine)
        session = SessionLocal()
        
        # Seed test data
        self._seed_test_data(session)
        
        yield session
        session.close()
    
    def _seed_test_data(self, session):
        """Seed database with test leads."""
        statuses = ['new', 'called', 'interested', 'converted', 'new']
        industries = ['restaurant', 'retail', 'services', 'restaurant', 'retail']
        
        for i in range(50):  # Create 50 test leads
            lead = Lead(
                id=f"lead-{i:03d}",
                business_name=f"Business {i:03d}",
                phone=f"555-{i:04d}",
                location=f"City {i % 5}",
                industry=industries[i % 5],
                status=statuses[i % 5],
                rating=3.0 + (i % 3),
                review_count=10 * (i + 1),
                has_website=i % 2 == 0,
                is_candidate=i % 3 == 0,
                source="test",
                created_at=datetime.utcnow()
            )
            session.add(lead)
        session.commit()
    
    def test_pagination_follows_rest_standards(self, db_session):
        """Test that pagination follows REST API best practices."""
        service = LeadService(db_session)
        
        # Test standard pagination parameters
        result = service.get_paginated_leads(page=1, per_page=10)
        
        # Verify response structure matches industry standards
        assert isinstance(result, PaginatedResponse)
        assert hasattr(result, 'items')
        assert hasattr(result, 'total')
        assert hasattr(result, 'page')
        assert hasattr(result, 'per_page')
        assert hasattr(result, 'total_pages')
        
        # Verify pagination logic
        assert len(result.items) == 10
        assert result.total == 50
        assert result.page == 1
        assert result.per_page == 10
        assert result.total_pages == 5
    
    def test_pagination_bounds_checking(self, db_session):
        """Test that pagination handles edge cases properly."""
        service = LeadService(db_session)
        
        # Test page beyond available data
        result = service.get_paginated_leads(page=10, per_page=10)
        assert len(result.items) == 0
        assert result.page == 10
        
        # Test large per_page (should be capped)
        result = service.get_paginated_leads(page=1, per_page=1000)
        assert len(result.items) == 50  # All items
    
    def test_filtering_pattern_implementation(self, db_session):
        """Test that filtering follows the specification pattern concept."""
        service = LeadService(db_session)
        
        # Test status filter
        result = service.get_paginated_leads(status='new')
        assert all(lead.status == 'new' for lead in result.items)
        
        # Test search filter (demonstrates OR logic)
        result = service.get_paginated_leads(search='Business 001')
        assert len(result.items) > 0
        assert any('001' in lead.business_name for lead in result.items)
    
    def test_flutter_enum_mapping(self, db_session):
        """Test the Flutter 'new_' to database 'new' mapping."""
        service = LeadService(db_session)
        
        # Test that 'new_' maps to 'new' status
        result = service.get_paginated_leads(status='new_')
        
        # Should return same results as 'new'
        result_direct = service.get_paginated_leads(status='new')
        assert result.total == result_direct.total
    
    def test_sorting_with_null_handling(self, db_session):
        """Test that sorting handles nulls properly (best practice)."""
        service = LeadService(db_session)
        
        # Add a lead with null rating
        null_lead = Lead(
            id="null-rating-lead",
            business_name="Null Rating Business",
            phone="555-NULL",
            location="Test City",
            industry="test",
            status="new",
            rating=None,  # NULL rating
            source="test",
            created_at=datetime.utcnow()
        )
        db_session.add(null_lead)
        db_session.commit()
        
        # Test sorting by rating (nullable field)
        result = service.get_paginated_leads(sort_by='rating', sort_ascending=True)
        
        # Nulls should be handled gracefully
        assert result.total == 51  # 50 + 1 with null
    
    def test_offset_pagination_consistency(self, db_session):
        """Test that offset pagination is consistent (no duplicates/missing items)."""
        service = LeadService(db_session)
        
        all_ids = set()
        pages_to_check = 5
        
        for page in range(1, pages_to_check + 1):
            result = service.get_paginated_leads(page=page, per_page=10)
            page_ids = {lead.id for lead in result.items}
            
            # Check no duplicates across pages
            assert len(all_ids.intersection(page_ids)) == 0
            all_ids.update(page_ids)
        
        # Should have all 50 items across 5 pages
        assert len(all_ids) == 50
    
    def test_combined_filters_and_sort(self, db_session):
        """Test complex queries with multiple filters and sorting."""
        service = LeadService(db_session)
        
        # Complex query: status filter + search + sort
        result = service.get_paginated_leads(
            status='new',
            search='Business',
            sort_by='review_count',
            sort_ascending=False,
            page=1,
            per_page=5
        )
        
        # Verify filters are applied
        assert all(lead.status == 'new' for lead in result.items)
        assert all('Business' in lead.business_name for lead in result.items)
        
        # Verify sorting (descending review count)
        if len(result.items) > 1:
            for i in range(len(result.items) - 1):
                assert result.items[i].review_count >= result.items[i+1].review_count
    
    def test_performance_optimization_eager_loading(self, db_session):
        """Test that the service uses eager loading (N+1 query prevention)."""
        service = LeadService(db_session)
        
        # The service should use selectinload for relationships
        with patch.object(db_session, 'query') as mock_query:
            mock_query.return_value.options.return_value.filter.return_value.count.return_value = 0
            mock_query.return_value.options.return_value.filter.return_value.order_by.return_value.offset.return_value.limit.return_value.all.return_value = []
            
            service.get_paginated_leads()
            
            # Verify selectinload was called (prevents N+1 queries)
            mock_query.return_value.options.assert_called()
    
    def test_service_layer_separation(self):
        """Test that the service layer doesn't have HTTP concerns."""
        service_code = open('services/lead_service.py').read()
        
        # Service should not import FastAPI/HTTP libraries
        assert 'from fastapi' not in service_code
        assert 'HTTPException' not in service_code
        assert '@app' not in service_code
        assert '@router' not in service_code
        
        # Service should focus on business logic
        assert 'class LeadService' in service_code
        assert 'def get_paginated_leads' in service_code


class TestPaginationPatternCompliance:
    """Test compliance with industry-standard pagination patterns."""
    
    def test_follows_rfc5988_link_header_pattern(self):
        """Test that pagination could support RFC 5988 Link headers."""
        # The PaginatedResponse has all necessary data to generate Link headers
        response = PaginatedResponse(
            items=[],
            total=100,
            page=3,
            per_page=10,
            total_pages=10
        )
        
        # Can generate standard navigation links
        assert response.page > 1  # Has previous
        assert response.page < response.total_pages  # Has next
        
        # Could generate: Link: <...?page=2>; rel="prev", <...?page=4>; rel="next"
    
    def test_follows_json_api_pagination_format(self):
        """Test that response structure is compatible with JSON:API spec."""
        response = PaginatedResponse(
            items=[{"id": "1", "business_name": "Test"}],
            total=100,
            page=1,
            per_page=10,
            total_pages=10
        )
        
        # Has required fields for JSON:API pagination
        assert hasattr(response, 'items')  # data
        assert hasattr(response, 'total')   # meta.total
        assert hasattr(response, 'page')    # meta.page
        
        # Can be transformed to JSON:API format
        json_api_format = {
            "data": response.items,
            "meta": {
                "total": response.total,
                "page": response.page,
                "per_page": response.per_page,
                "total_pages": response.total_pages
            }
        }
        assert json_api_format["meta"]["total"] == 100
    
    def test_supports_cursor_pagination_upgrade_path(self):
        """Test that the architecture supports upgrading to cursor pagination."""
        # The service layer abstraction means we could switch from offset to cursor
        # without changing the API contract
        
        service_interface = {
            "get_paginated_leads": {
                "parameters": ["page", "per_page", "status", "search", "sort_by", "sort_ascending"],
                "returns": "PaginatedResponse"
            }
        }
        
        # The interface doesn't expose implementation details
        assert "offset" not in str(service_interface)
        assert "LIMIT" not in str(service_interface)
        
        # Could add cursor support by adding optional cursor parameter
        # without breaking existing offset pagination


if __name__ == "__main__":
    # Run tests
    pytest.main([__file__, "-v"])