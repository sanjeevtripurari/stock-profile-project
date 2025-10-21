#!/bin/bash

echo "🧹 Clearing Portfolio Cache and Testing"
echo "======================================"

# Get token (assuming you're logged in)
TOKEN=$(curl -s -X POST http://localhost/api/users/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }' | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo "❌ No token found. Please register/login first"
  exit 1
fi

echo "✅ Token obtained"

# Clear cache
echo "Clearing portfolio cache..."
curl -s -X DELETE http://localhost/api/portfolio/cache \
  -H "Authorization: Bearer $TOKEN"

echo "✅ Cache cleared"

# Get fresh portfolio data
echo "Fetching fresh portfolio data..."
PORTFOLIO=$(curl -s http://localhost/api/portfolio/tickers \
  -H "Authorization: Bearer $TOKEN")

echo "Portfolio Response:"
echo "$PORTFOLIO" | jq '.' 2>/dev/null || echo "$PORTFOLIO"

echo "✅ Test completed"