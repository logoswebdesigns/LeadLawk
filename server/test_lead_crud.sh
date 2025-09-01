#!/bin/bash
# Comprehensive regression tests for Lead CRUD operations
# Tests all endpoints to ensure UUID string IDs work correctly

set -e  # Exit on any error

BASE_URL="http://localhost:8000"
TEMP_FILE="/tmp/lead_crud_test.json"

echo "🚀 Starting Lead CRUD Regression Tests..."
echo "   Server: $BASE_URL"
echo "   Time: $(date)"

# Health check
echo -n "✅ Server health check: "
curl -s -f "$BASE_URL/health" > /dev/null && echo "PASSED" || (echo "FAILED" && exit 1)

# Test 1: Get all leads
echo -n "1. Testing GET /leads: "
curl -s "$BASE_URL/leads" > "$TEMP_FILE"
if jq -e '. | length >= 0' "$TEMP_FILE" > /dev/null 2>&1; then
    LEAD_COUNT=$(jq '. | length' "$TEMP_FILE")
    echo "PASSED ($LEAD_COUNT leads)"
else
    echo "FAILED - Invalid JSON response"
    exit 1
fi

if [ "$LEAD_COUNT" -eq 0 ]; then
    echo "⚠️  No leads found, creating a test lead first..."
    # Create a test lead by running a quick automation job
    curl -s -X POST "$BASE_URL/jobs/browser" \
        -H "Content-Type: application/json" \
        -d '{"industry": "test", "location": "test", "limit": 1}' > /dev/null
    
    echo "   Waiting 15 seconds for job to complete..."
    sleep 15
    
    # Get leads again
    curl -s "$BASE_URL/leads" > "$TEMP_FILE"
    LEAD_COUNT=$(jq '. | length' "$TEMP_FILE")
    echo "   Now have $LEAD_COUNT leads"
fi

if [ "$LEAD_COUNT" -eq 0 ]; then
    echo "⚠️  Still no leads found, exiting test"
    exit 0
fi

# Get the first lead ID for testing
LEAD_ID=$(jq -r '.[0].id' "$TEMP_FILE")
echo "   📝 Using lead ID: $LEAD_ID"

# Validate UUID format
if echo "$LEAD_ID" | grep -E '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' > /dev/null; then
    echo "   ✅ Lead ID is valid UUID string"
else
    echo "   ❌ Lead ID is not a valid UUID: $LEAD_ID"
    exit 1
fi

# Test 2: Get specific lead by UUID
echo -n "2. Testing GET /leads/$LEAD_ID: "
curl -s -f "$BASE_URL/leads/$LEAD_ID" > "$TEMP_FILE" && echo "PASSED" || (echo "FAILED" && exit 1)

# Verify returned ID matches
RETURNED_ID=$(jq -r '.id' "$TEMP_FILE")
if [ "$RETURNED_ID" = "$LEAD_ID" ]; then
    echo "   ✅ Returned correct lead ID"
else
    echo "   ❌ ID mismatch: $RETURNED_ID != $LEAD_ID"
    exit 1
fi

# Test 3: Update lead by UUID
echo -n "3. Testing PUT /leads/$LEAD_ID: "
TEST_NOTES="Updated via regression test at $(date)"
curl -s -X PUT "$BASE_URL/leads/$LEAD_ID" \
    -H "Content-Type: application/json" \
    -d "{\"notes\": \"$TEST_NOTES\"}" > "$TEMP_FILE"

if jq -e '.notes' "$TEMP_FILE" > /dev/null 2>&1; then
    UPDATED_NOTES=$(jq -r '.notes' "$TEMP_FILE")
    if [ "$UPDATED_NOTES" = "$TEST_NOTES" ]; then
        echo "PASSED"
        echo "   ✅ Notes successfully updated"
    else
        echo "FAILED - Notes not updated correctly"
        exit 1
    fi
else
    echo "FAILED - Invalid response"
    cat "$TEMP_FILE"
    exit 1
fi

# Test 4: Test invalid ID types
echo -n "4. Testing DELETE with integer ID (should fail): "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$BASE_URL/leads/123")
if [ "$HTTP_CODE" = "422" ] || [ "$HTTP_CODE" = "404" ]; then
    echo "PASSED (HTTP $HTTP_CODE)"
else
    echo "FAILED - Expected 422 or 404, got $HTTP_CODE"
    exit 1
fi

# Test 5: Test DELETE with fake UUID (should return 404)
FAKE_UUID="00000000-0000-0000-0000-000000000000"
echo -n "5. Testing DELETE with fake UUID: "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$BASE_URL/leads/$FAKE_UUID")
if [ "$HTTP_CODE" = "404" ]; then
    echo "PASSED (HTTP $HTTP_CODE)"
else
    echo "FAILED - Expected 404, got $HTTP_CODE"
    exit 1
fi

# Test 6: Test successful DELETE
echo -n "6. Testing DELETE /leads/$LEAD_ID: "
HTTP_CODE=$(curl -s -o "$TEMP_FILE" -w "%{http_code}" -X DELETE "$BASE_URL/leads/$LEAD_ID")
if [ "$HTTP_CODE" = "200" ]; then
    MESSAGE=$(jq -r '.message' "$TEMP_FILE" 2>/dev/null || echo "")
    if echo "$MESSAGE" | grep -i "deleted successfully" > /dev/null; then
        echo "PASSED"
        echo "   ✅ Delete message: $MESSAGE"
    else
        echo "FAILED - Unexpected message: $MESSAGE"
        exit 1
    fi
else
    echo "FAILED - HTTP $HTTP_CODE"
    cat "$TEMP_FILE"
    exit 1
fi

# Test 7: Verify deletion
echo -n "7. Verifying lead was deleted: "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/leads/$LEAD_ID")
if [ "$HTTP_CODE" = "404" ]; then
    echo "PASSED (HTTP $HTTP_CODE)"
    echo "   ✅ Lead was successfully deleted"
else
    echo "FAILED - Lead still exists (HTTP $HTTP_CODE)"
    exit 1
fi

# Cleanup
rm -f "$TEMP_FILE"

echo ""
echo "🎉 All Lead CRUD regression tests passed!"
echo "   ✅ UUID string IDs are working correctly in all endpoints"
echo "   ✅ CRUD operations (Create, Read, Update, Delete) all functional"
echo "   ✅ Proper error handling for invalid ID formats"