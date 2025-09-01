#!/bin/bash

# Anti-regression test for PageSpeed parameter parsing
# Tests that enable_pagespeed is correctly parsed from request body

echo "🧪 Testing PageSpeed parameter parsing..."

# Test with enable_pagespeed: true
echo "📤 Testing with enable_pagespeed: true"
response=$(curl -s -X POST http://localhost:8000/jobs/parallel \
  -H "Content-Type: application/json" \
  -d '{
    "industries": ["test_industry"],
    "locations": ["test_location"],
    "limit": 1,
    "min_rating": 4.0,
    "min_reviews": 1,
    "requires_website": null,
    "recent_review_months": 24,
    "enable_pagespeed": true
  }')

if echo "$response" | grep -q "parent_job_id"; then
  echo "✅ Server accepted enable_pagespeed: true"
else
  echo "❌ Test failed with enable_pagespeed: true"
  echo "Response: $response"
  exit 1
fi

# Test with enable_pagespeed: false
echo "📤 Testing with enable_pagespeed: false"
response=$(curl -s -X POST http://localhost:8000/jobs/parallel \
  -H "Content-Type: application/json" \
  -d '{
    "industries": ["test_industry"],
    "locations": ["test_location"],
    "limit": 1,
    "min_rating": 4.0,
    "min_reviews": 1,
    "requires_website": null,
    "recent_review_months": 24,
    "enable_pagespeed": false
  }')

if echo "$response" | grep -q "parent_job_id"; then
  echo "✅ Server accepted enable_pagespeed: false"
else
  echo "❌ Test failed with enable_pagespeed: false"
  echo "Response: $response"
  exit 1
fi

# Test without enable_pagespeed (should use default)
echo "📤 Testing without enable_pagespeed (should default to false)"
response=$(curl -s -X POST http://localhost:8000/jobs/parallel \
  -H "Content-Type: application/json" \
  -d '{
    "industries": ["test_industry"],
    "locations": ["test_location"],
    "limit": 1,
    "min_rating": 4.0,
    "min_reviews": 1,
    "requires_website": null,
    "recent_review_months": 24
  }')

if echo "$response" | grep -q "parent_job_id"; then
  echo "✅ Server accepted request without enable_pagespeed"
else
  echo "❌ Test failed without enable_pagespeed"
  echo "Response: $response"
  exit 1
fi

echo ""
echo "🎉 All PageSpeed parameter tests passed!"
echo ""
echo "To verify the parameter is being used correctly, check server logs:"
echo "docker logs leadloq-api --tail 50 | grep enable_pagespeed"