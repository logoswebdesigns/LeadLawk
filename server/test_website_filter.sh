#!/bin/bash

# Test website filter with all three states

echo "🧪 Testing Website Filter States..."
echo "=================================================="

# Test 1: requires_website = null (both)
echo ""
echo "📤 Test 1: requires_website = null (get BOTH)"
curl -s -X POST http://localhost:8000/jobs/parallel \
  -H "Content-Type: application/json" \
  -d '{
    "industries": ["painter"],
    "locations": ["Omaha, NE"],
    "limit": 3,
    "min_rating": 4.0,
    "min_reviews": 5,
    "requires_website": null,
    "recent_review_months": 24,
    "enable_pagespeed": true
  }' | python3 -m json.tool

echo "Waiting for job to complete..."
sleep 10

echo "Checking logs for website filter..."
docker logs leadloq-api --tail 30 | grep -E "Website filter|has_website|No website|Found website" | tail -5

# Test 2: requires_website = true (only with websites)
echo ""
echo "📤 Test 2: requires_website = true (ONLY with websites)"
curl -s -X POST http://localhost:8000/jobs/parallel \
  -H "Content-Type: application/json" \
  -d '{
    "industries": ["electrician"],
    "locations": ["Omaha, NE"],
    "limit": 3,
    "min_rating": 4.0,
    "min_reviews": 5,
    "requires_website": true,
    "recent_review_months": 24,
    "enable_pagespeed": true
  }' | python3 -m json.tool

echo "Waiting for job to complete..."
sleep 10

echo "Checking logs for website filter..."
docker logs leadloq-api --tail 30 | grep -E "Website filter|Business filtered out.*website" | tail -5

# Test 3: requires_website = false (only without websites)  
echo ""
echo "📤 Test 3: requires_website = false (ONLY without websites)"
curl -s -X POST http://localhost:8000/jobs/parallel \
  -H "Content-Type: application/json" \
  -d '{
    "industries": ["landscaper"],
    "locations": ["Omaha, NE"],
    "limit": 3,
    "min_rating": 4.0,
    "min_reviews": 5,
    "requires_website": false,
    "recent_review_months": 24,
    "enable_pagespeed": false
  }' | python3 -m json.tool

echo "Waiting for job to complete..."
sleep 10

echo "Checking logs for website filter..."
docker logs leadloq-api --tail 30 | grep -E "Website filter|Business filtered out.*website" | tail -5

echo ""
echo "=================================================="
echo "🎉 Website filter tests complete!"
echo ""
echo "Checking database for recent leads..."
sqlite3 /Users/jacobanderson/Documents/GitHub/LeadLawk/server/db/leadloq.db "
SELECT 
  substr(business_name, 1, 30) as name,
  CASE has_website WHEN 1 THEN 'YES' ELSE 'NO' END as has_site,
  CASE WHEN website_url IS NOT NULL THEN 'HAS URL' ELSE 'NO URL' END as url_status,
  CASE WHEN pagespeed_mobile_score IS NOT NULL THEN pagespeed_mobile_score ELSE '-' END as ps_score
FROM leads 
WHERE created_at > datetime('now', '-2 minutes')
ORDER BY created_at DESC
LIMIT 10;"