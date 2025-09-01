#!/bin/bash

# Quick verification script for the 4 business listing scenarios
# Run this after any changes to verify extraction is working

echo "🧪 Quick Business Listing Extraction Test"
echo "=========================================="
echo ""

# Function to test a search
test_search() {
    local query="$1"
    local expected_type="$2"
    
    echo "📍 Testing: $query"
    echo "   Expected: $expected_type listings"
    
    # Start the search
    response=$(curl -s -X POST http://localhost:8000/api/browser/start \
        -H "Content-Type: application/json" \
        -d "{
            \"query\": \"$query\",
            \"limit\": 5,
            \"min_rating\": 0,
            \"min_reviews\": 0,
            \"requires_website\": null,
            \"enable_click_through\": true
        }")
    
    job_id=$(echo "$response" | grep -o '"job_id":"[^"]*' | cut -d'"' -f4)
    
    if [ -z "$job_id" ]; then
        echo "   ❌ Failed to start search"
        return 1
    fi
    
    echo "   Job ID: $job_id"
    
    # Wait for completion (max 60 seconds)
    for i in {1..12}; do
        sleep 5
        status=$(curl -s http://localhost:8000/api/browser/status/$job_id | grep -o '"status":"[^"]*' | cut -d'"' -f4)
        
        if [ "$status" = "completed" ]; then
            echo "   ✅ Search completed"
            
            # Get results
            results=$(curl -s "http://localhost:8000/api/leads?job_id=$job_id")
            
            # Count businesses with and without websites
            total=$(echo "$results" | grep -o '"business_name"' | wc -l)
            with_website=$(echo "$results" | grep -o '"website_url":"[^"]*"' | grep -v ':"null"' | wc -l)
            without_website=$((total - with_website))
            
            echo "   Results: $total businesses found"
            echo "   - With website: $with_website"
            echo "   - Without website: $without_website"
            
            if [ $with_website -gt 0 ]; then
                echo "   ✅ Website extraction working for $expected_type listings!"
            else
                echo "   ⚠️ No websites found - may indicate extraction issue"
            fi
            
            echo ""
            return 0
        elif [ "$status" = "failed" ]; then
            echo "   ❌ Search failed"
            return 1
        fi
    done
    
    echo "   ⏱️ Search timed out"
    return 1
}

# Test standard listings (painters)
echo "1️⃣ STANDARD LISTINGS TEST"
echo "------------------------"
test_search "painter papillion" "STANDARD"

# Test compact listings (dentists)
echo "2️⃣ COMPACT LISTINGS TEST"
echo "----------------------"
test_search "dentist papillion" "COMPACT"

echo "=========================================="
echo "✅ Test complete!"
echo ""
echo "If both tests found websites, the extraction is working correctly."
echo "If compact listings found no websites, the click-through may be broken."