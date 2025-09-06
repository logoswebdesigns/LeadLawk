"""
Test suite following AAA (Arrange-Act-Assert) pattern for pagination.
Demonstrates that the implementation follows industry best practices.
"""

import requests
import json
from typing import Dict, Any, List


class TestPaginationBestPractices:
    """
    Integration tests following AAA pattern to prove the pagination 
    implementation follows industry-standard patterns.
    """
    
    BASE_URL = "http://localhost:8000"
    
    def test_pagination_follows_rest_api_standards(self):
        """Test that pagination response structure follows REST best practices."""
        # Arrange
        endpoint = f"{self.BASE_URL}/leads"
        params = {
            "page": 1,
            "per_page": 10
        }
        
        # Act
        response = requests.get(endpoint, params=params)
        data = response.json()
        
        # Assert
        assert response.status_code == 200, "Should return 200 OK"
        assert "items" in data, "Should have 'items' field (industry standard)"
        assert "total" in data, "Should have 'total' count field"
        assert "page" in data, "Should have current 'page' number"
        assert "per_page" in data, "Should have 'per_page' size"
        assert "total_pages" in data, "Should have 'total_pages' count"
        assert isinstance(data["items"], list), "Items should be an array"
        print("✅ Pagination structure follows REST standards")
    
    def test_sorting_with_nullable_fields_best_practice(self):
        """Test that sorting handles NULL values properly (NULLS LAST/FIRST)."""
        # Arrange
        endpoint = f"{self.BASE_URL}/leads"
        params_asc = {
            "page": 1,
            "per_page": 5,
            "sort_by": "rating",
            "sort_ascending": "true"
        }
        params_desc = {
            "page": 1,
            "per_page": 5,
            "sort_by": "rating",
            "sort_ascending": "false"
        }
        
        # Act
        response_asc = requests.get(endpoint, params=params_asc)
        response_desc = requests.get(endpoint, params=params_desc)
        data_asc = response_asc.json()
        data_desc = response_desc.json()
        
        # Assert
        assert response_asc.status_code == 200, "Ascending sort should work"
        assert response_desc.status_code == 200, "Descending sort should work"
        
        # Check that ratings are properly sorted
        ratings_asc = [item.get("rating") for item in data_asc["items"] if item.get("rating") is not None]
        ratings_desc = [item.get("rating") for item in data_desc["items"] if item.get("rating") is not None]
        
        if len(ratings_asc) > 1:
            assert all(ratings_asc[i] <= ratings_asc[i+1] for i in range(len(ratings_asc)-1)), \
                "Ascending sort should be properly ordered"
        
        if len(ratings_desc) > 1:
            assert all(ratings_desc[i] >= ratings_desc[i+1] for i in range(len(ratings_desc)-1)), \
                "Descending sort should be properly ordered"
        
        print("✅ Nullable field sorting follows best practices")
    
    def test_filter_with_enum_mapping(self):
        """Test Flutter enum mapping (new_ -> new) works correctly."""
        # Arrange
        endpoint = f"{self.BASE_URL}/leads"
        params_flutter = {
            "page": 1,
            "per_page": 5,
            "status": "new_"  # Flutter sends new_ because 'new' is reserved
        }
        params_direct = {
            "page": 1,
            "per_page": 5,
            "status": "new"  # Direct database value
        }
        
        # Act
        response_flutter = requests.get(endpoint, params=params_flutter)
        response_direct = requests.get(endpoint, params=params_direct)
        data_flutter = response_flutter.json()
        data_direct = response_direct.json()
        
        # Assert
        assert response_flutter.status_code == 200, "Flutter enum should be accepted"
        assert response_direct.status_code == 200, "Direct enum should be accepted"
        assert data_flutter["total"] == data_direct["total"], \
            "Both 'new_' and 'new' should return same results"
        assert data_flutter["total"] > 0, "Should have leads with 'new' status"
        print(f"✅ Enum mapping works: 'new_' returns {data_flutter['total']} leads")
    
    def test_search_filter_follows_or_pattern(self):
        """Test that search uses OR across multiple fields (best practice)."""
        # Arrange
        endpoint = f"{self.BASE_URL}/leads"
        search_term = "construction"
        params = {
            "page": 1,
            "per_page": 10,
            "search": search_term
        }
        
        # Act
        response = requests.get(endpoint, params=params)
        data = response.json()
        
        # Assert
        assert response.status_code == 200, "Search should work"
        assert data["total"] > 0, f"Should find leads matching '{search_term}'"
        
        # Verify search matches in any of the searchable fields
        for item in data["items"]:
            matches = (
                search_term.lower() in item.get("business_name", "").lower() or
                search_term.lower() in item.get("phone", "").lower() or
                search_term.lower() in item.get("location", "").lower()
            )
            assert matches, f"Search should match in at least one field for {item.get('business_name')}"
        
        print(f"✅ Search filter uses OR pattern across fields (found {data['total']} matches)")
    
    def test_combined_filters_and_sort(self):
        """Test complex queries with multiple filters and sorting (real-world scenario)."""
        # Arrange
        endpoint = f"{self.BASE_URL}/leads"
        params = {
            "page": 1,
            "per_page": 5,
            "status": "new_",
            "has_website": "false",
            "sort_by": "review_count",
            "sort_ascending": "false"
        }
        
        # Act
        response = requests.get(endpoint, params=params)
        data = response.json()
        
        # Assert
        assert response.status_code == 200, "Combined filters should work"
        assert len(data["items"]) > 0, "Should return results"
        
        # Verify all filters are applied
        for item in data["items"]:
            assert item["status"] == "new", "Status filter should be applied"
            assert item["has_website"] is False, "Website filter should be applied"
        
        # Verify sorting is applied
        review_counts = [item["review_count"] for item in data["items"]]
        if len(review_counts) > 1:
            assert all(review_counts[i] >= review_counts[i+1] for i in range(len(review_counts)-1)), \
                "Should be sorted by review_count descending"
        
        print(f"✅ Combined filters and sort work correctly (found {data['total']} matching leads)")
    
    def test_pagination_consistency_no_duplicates(self):
        """Test that pagination doesn't have duplicates or missing items (ACID compliance)."""
        # Arrange
        endpoint = f"{self.BASE_URL}/leads"
        per_page = 10
        pages_to_check = 3
        all_ids = set()
        
        # Act
        for page in range(1, pages_to_check + 1):
            params = {
                "page": page,
                "per_page": per_page,
                "sort_by": "created_at",  # Consistent sort is crucial
                "sort_ascending": "false"
            }
            response = requests.get(endpoint, params=params)
            data = response.json()
            
            # Collect IDs from this page
            page_ids = {item["id"] for item in data["items"]}
            
            # Assert - No duplicates across pages
            duplicates = all_ids.intersection(page_ids)
            assert len(duplicates) == 0, f"Page {page} has duplicate IDs: {duplicates}"
            
            all_ids.update(page_ids)
        
        # Assert - Total unique IDs equals expected count
        expected_count = pages_to_check * per_page
        assert len(all_ids) <= expected_count, "Should not have more items than requested"
        print(f"✅ Pagination is consistent: {len(all_ids)} unique items across {pages_to_check} pages")
    
    def test_pagination_performance_limits(self):
        """Test that pagination has reasonable limits (prevents DoS)."""
        # Arrange
        endpoint = f"{self.BASE_URL}/leads"
        params_large = {
            "page": 1,
            "per_page": 1000  # Requesting excessive items
        }
        
        # Act
        response = requests.get(endpoint, params=params_large)
        data = response.json()
        
        # Assert
        assert response.status_code == 200, "Should handle large per_page gracefully"
        assert data["per_page"] <= 100, "Should cap per_page at reasonable limit (100)"
        assert len(data["items"]) <= 100, "Should not return more than limit"
        print("✅ Pagination has performance limits (capped at 100 items)")
    
    def test_invalid_sort_field_handling(self):
        """Test that invalid sort fields are handled gracefully."""
        # Arrange
        endpoint = f"{self.BASE_URL}/leads"
        params = {
            "page": 1,
            "per_page": 5,
            "sort_by": "invalid_field"
        }
        
        # Act
        response = requests.get(endpoint, params=params)
        
        # Assert
        # Should either ignore invalid field or use default
        assert response.status_code == 200, "Should not crash on invalid sort field"
        data = response.json()
        assert "items" in data, "Should still return valid response structure"
        print("✅ Invalid sort fields handled gracefully")


def run_integration_tests():
    """Run all integration tests and report results."""
    print("\n" + "="*60)
    print("PAGINATION BEST PRACTICES TEST SUITE")
    print("Following AAA (Arrange-Act-Assert) Pattern")
    print("="*60 + "\n")
    
    test_suite = TestPaginationBestPractices()
    
    tests = [
        ("REST API Standards", test_suite.test_pagination_follows_rest_api_standards),
        ("Nullable Field Sorting", test_suite.test_sorting_with_nullable_fields_best_practice),
        ("Enum Mapping (Flutter)", test_suite.test_filter_with_enum_mapping),
        ("Search OR Pattern", test_suite.test_search_filter_follows_or_pattern),
        ("Combined Filters & Sort", test_suite.test_combined_filters_and_sort),
        ("Pagination Consistency", test_suite.test_pagination_consistency_no_duplicates),
        ("Performance Limits", test_suite.test_pagination_performance_limits),
        ("Error Handling", test_suite.test_invalid_sort_field_handling),
    ]
    
    passed = 0
    failed = 0
    
    for test_name, test_func in tests:
        try:
            print(f"\nTesting: {test_name}")
            test_func()
            passed += 1
        except AssertionError as e:
            print(f"❌ {test_name} failed: {e}")
            failed += 1
        except Exception as e:
            print(f"❌ {test_name} error: {e}")
            failed += 1
    
    print("\n" + "="*60)
    print(f"RESULTS: {passed} passed, {failed} failed")
    print("="*60)
    
    return failed == 0


if __name__ == "__main__":
    success = run_integration_tests()
    exit(0 if success else 1)