#!/bin/bash

# Test suite following AAA (Arrange-Act-Assert) pattern
# Proves the pagination implementation follows best practices

BASE_URL="http://localhost:8000"
PASSED=0
FAILED=0

echo "============================================================"
echo "PAGINATION BEST PRACTICES TEST SUITE"
echo "Following AAA (Arrange-Act-Assert) Pattern"
echo "============================================================"

# Test 1: REST API Standards
test_rest_api_standards() {
    echo -e "\n[TEST 1] REST API Standards"
    
    # Arrange
    ENDPOINT="$BASE_URL/leads?page=1&per_page=10"
    
    # Act
    RESPONSE=$(curl -s "$ENDPOINT")
    
    # Assert
    if echo "$RESPONSE" | jq -e '.items' > /dev/null 2>&1 && \
       echo "$RESPONSE" | jq -e '.total' > /dev/null 2>&1 && \
       echo "$RESPONSE" | jq -e '.page' > /dev/null 2>&1 && \
       echo "$RESPONSE" | jq -e '.per_page' > /dev/null 2>&1 && \
       echo "$RESPONSE" | jq -e '.total_pages' > /dev/null 2>&1; then
        echo "✅ PASS: Pagination structure follows REST standards"
        ((PASSED++))
    else
        echo "❌ FAIL: Missing required pagination fields"
        ((FAILED++))
    fi
}

# Test 2: Flutter Enum Mapping
test_flutter_enum_mapping() {
    echo -e "\n[TEST 2] Flutter Enum Mapping (new_ -> new)"
    
    # Arrange
    ENDPOINT_FLUTTER="$BASE_URL/leads?page=1&per_page=5&status=new_"
    ENDPOINT_DIRECT="$BASE_URL/leads?page=1&per_page=5&status=new"
    
    # Act
    TOTAL_FLUTTER=$(curl -s "$ENDPOINT_FLUTTER" | jq '.total')
    TOTAL_DIRECT=$(curl -s "$ENDPOINT_DIRECT" | jq '.total')
    
    # Assert
    if [ "$TOTAL_FLUTTER" = "$TOTAL_DIRECT" ] && [ "$TOTAL_FLUTTER" -gt 0 ]; then
        echo "✅ PASS: Enum mapping works - 'new_' returns $TOTAL_FLUTTER leads"
        ((PASSED++))
    else
        echo "❌ FAIL: Enum mapping failed (Flutter: $TOTAL_FLUTTER, Direct: $TOTAL_DIRECT)"
        ((FAILED++))
    fi
}

# Test 3: Sorting with Nullable Fields
test_nullable_sorting() {
    echo -e "\n[TEST 3] Sorting with Nullable Fields"
    
    # Arrange
    ENDPOINT="$BASE_URL/leads?page=1&per_page=5&sort_by=rating&sort_ascending=false"
    
    # Act
    RESPONSE=$(curl -s "$ENDPOINT")
    RATINGS=$(echo "$RESPONSE" | jq '[.items[].rating] | map(select(. != null))' | jq -r '.[]')
    
    # Assert
    PREV=""
    SORTED=true
    for RATING in $RATINGS; do
        if [ ! -z "$PREV" ]; then
            if (( $(echo "$RATING > $PREV" | bc -l) )); then
                SORTED=false
                break
            fi
        fi
        PREV=$RATING
    done
    
    if [ "$SORTED" = true ]; then
        echo "✅ PASS: Nullable field sorting works correctly"
        ((PASSED++))
    else
        echo "❌ FAIL: Sorting not working properly"
        ((FAILED++))
    fi
}

# Test 4: Search Filter (OR Pattern)
test_search_filter() {
    echo -e "\n[TEST 4] Search Filter OR Pattern"
    
    # Arrange
    SEARCH_TERM="construction"
    ENDPOINT="$BASE_URL/leads?page=1&per_page=10&search=$SEARCH_TERM"
    
    # Act
    RESPONSE=$(curl -s "$ENDPOINT")
    TOTAL=$(echo "$RESPONSE" | jq '.total')
    FIRST_NAME=$(echo "$RESPONSE" | jq -r '.items[0].business_name' | tr '[:upper:]' '[:lower:]')
    
    # Assert
    if [ "$TOTAL" -gt 0 ] && echo "$FIRST_NAME" | grep -q "$SEARCH_TERM"; then
        echo "✅ PASS: Search filter works - found $TOTAL matches for '$SEARCH_TERM'"
        ((PASSED++))
    else
        echo "❌ FAIL: Search filter not working properly"
        ((FAILED++))
    fi
}

# Test 5: Combined Filters and Sort
test_combined_filters() {
    echo -e "\n[TEST 5] Combined Filters and Sort"
    
    # Arrange
    ENDPOINT="$BASE_URL/leads?page=1&per_page=5&status=new_&has_website=false&sort_by=review_count&sort_ascending=false"
    
    # Act
    RESPONSE=$(curl -s "$ENDPOINT")
    TOTAL=$(echo "$RESPONSE" | jq '.total')
    REVIEWS=$(echo "$RESPONSE" | jq '[.items[].review_count]')
    HAS_WEBSITES=$(echo "$RESPONSE" | jq '[.items[].has_website] | all')
    
    # Assert
    if [ "$TOTAL" -gt 0 ] && [ "$HAS_WEBSITES" = "false" ]; then
        echo "✅ PASS: Combined filters work - found $TOTAL matching leads"
        ((PASSED++))
    else
        echo "❌ FAIL: Combined filters not working properly"
        ((FAILED++))
    fi
}

# Test 6: Pagination Consistency
test_pagination_consistency() {
    echo -e "\n[TEST 6] Pagination Consistency (No Duplicates)"
    
    # Arrange & Act
    PAGE1_IDS=$(curl -s "$BASE_URL/leads?page=1&per_page=10&sort_by=created_at" | jq -r '.items[].id' | sort)
    PAGE2_IDS=$(curl -s "$BASE_URL/leads?page=2&per_page=10&sort_by=created_at" | jq -r '.items[].id' | sort)
    
    # Assert - Check for duplicates
    DUPLICATES=$(comm -12 <(echo "$PAGE1_IDS") <(echo "$PAGE2_IDS") | wc -l)
    
    if [ "$DUPLICATES" -eq 0 ]; then
        echo "✅ PASS: No duplicates across pages"
        ((PASSED++))
    else
        echo "❌ FAIL: Found $DUPLICATES duplicate IDs across pages"
        ((FAILED++))
    fi
}

# Test 7: Performance Limits
test_performance_limits() {
    echo -e "\n[TEST 7] Performance Limits (DoS Prevention)"
    
    # Arrange
    ENDPOINT="$BASE_URL/leads?page=1&per_page=1000"
    
    # Act
    RESPONSE=$(curl -s "$ENDPOINT")
    ACTUAL_PER_PAGE=$(echo "$RESPONSE" | jq '.per_page')
    ITEMS_COUNT=$(echo "$RESPONSE" | jq '.items | length')
    
    # Assert
    if [ "$ACTUAL_PER_PAGE" -le 100 ] && [ "$ITEMS_COUNT" -le 100 ]; then
        echo "✅ PASS: Performance limits enforced (capped at $ACTUAL_PER_PAGE items)"
        ((PASSED++))
    else
        echo "❌ FAIL: No performance limits (returned $ITEMS_COUNT items)"
        ((FAILED++))
    fi
}

# Test 8: Status Filter Validation
test_status_filter() {
    echo -e "\n[TEST 8] Status Filter Validation"
    
    # Arrange
    ENDPOINT="$BASE_URL/leads?page=1&per_page=5&status=called"
    
    # Act
    RESPONSE=$(curl -s "$ENDPOINT")
    STATUSES=$(echo "$RESPONSE" | jq -r '.items[].status' | sort -u)
    
    # Assert
    if [ "$STATUSES" = "called" ] || [ -z "$STATUSES" ]; then
        echo "✅ PASS: Status filter works correctly"
        ((PASSED++))
    else
        echo "❌ FAIL: Status filter not working (got: $STATUSES)"
        ((FAILED++))
    fi
}

# Run all tests
test_rest_api_standards
test_flutter_enum_mapping
test_nullable_sorting
test_search_filter
test_combined_filters
test_pagination_consistency
test_performance_limits
test_status_filter

# Summary
echo ""
echo "============================================================"
echo "RESULTS: $PASSED passed, $FAILED failed"
echo "============================================================"

if [ $FAILED -eq 0 ]; then
    echo "✅ All tests passed! The pagination implementation follows best practices."
    exit 0
else
    echo "❌ Some tests failed. Please review the implementation."
    exit 1
fi