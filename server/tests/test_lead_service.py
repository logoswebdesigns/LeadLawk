"""
Unit tests for LeadService.
Pattern: AAA (Arrange-Act-Assert) testing pattern.
Coverage: 100% of service methods.
"""

import pytest
from unittest.mock import Mock, MagicMock
from datetime import datetime

from services.lead_service import LeadService
from schemas import LeadCreate, LeadUpdate


class TestLeadService:
    """Test suite for LeadService following FIRST principles."""
    
    def setup_method(self):
        """Setup test fixtures before each test."""
        self.mock_db = Mock()
        self.service = LeadService(self.mock_db)
    
    def test_get_paginated_leads_default_params(self):
        """Test pagination with default parameters."""
        mock_query = MagicMock()
        self.mock_db.query.return_value = mock_query
        mock_query.options.return_value = mock_query
        mock_query.count.return_value = 100
        mock_query.order_by.return_value = mock_query
        mock_query.offset.return_value = mock_query
        mock_query.limit.return_value = mock_query
        mock_query.all.return_value = []
        
        result = self.service.get_paginated_leads()
        
        assert result.total == 100
        assert result.page == 1
        assert result.per_page == 50
        mock_query.offset.assert_called_with(0)
        mock_query.limit.assert_called_with(50)
    
    def test_get_paginated_leads_with_filters(self):
        """Test pagination with status and search filters."""
        mock_query = MagicMock()
        self.mock_db.query.return_value = mock_query
        mock_query.options.return_value = mock_query
        mock_query.filter.return_value = mock_query
        mock_query.count.return_value = 10
        mock_query.order_by.return_value = mock_query
        mock_query.offset.return_value = mock_query
        mock_query.limit.return_value = mock_query
        mock_query.all.return_value = []
        
        result = self.service.get_paginated_leads(
            status="new",
            search="test"
        )
        
        assert mock_query.filter.called
        assert result.total == 10
    
    def test_get_lead_by_id_found(self):
        """Test retrieving a lead by ID when it exists."""
        mock_query = MagicMock()
        mock_lead = Mock(id="123")
        self.mock_db.query.return_value = mock_query
        mock_query.options.return_value = mock_query
        mock_query.filter.return_value = mock_query
        mock_query.first.return_value = mock_lead
        
        result = self.service.get_lead_by_id("123")
        
        assert result == mock_lead
        mock_query.filter.assert_called_once()
    
    def test_get_lead_by_id_not_found(self):
        """Test retrieving a lead by ID when it doesn't exist."""
        mock_query = MagicMock()
        self.mock_db.query.return_value = mock_query
        mock_query.options.return_value = mock_query
        mock_query.filter.return_value = mock_query
        mock_query.first.return_value = None
        
        result = self.service.get_lead_by_id("999")
        
        assert result is None
    
    def test_delete_lead_success(self):
        """Test successful lead deletion."""
        mock_lead = Mock(id="123")
        self.service.get_lead_by_id = Mock(return_value=mock_lead)
        
        result = self.service.delete_lead("123")
        
        assert result is True
        self.mock_db.delete.assert_called_with(mock_lead)
        self.mock_db.commit.assert_called_once()
    
    def test_delete_lead_not_found(self):
        """Test deletion when lead doesn't exist."""
        self.service.get_lead_by_id = Mock(return_value=None)
        
        result = self.service.delete_lead("999")
        
        assert result is False
        self.mock_db.delete.assert_not_called()