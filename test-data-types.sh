#!/bin/bash

echo "🧪 Testing Data Type Consistency"
echo "==============================="

# Test adding a ticker with decimal values
echo "Testing ticker addition with decimal values..."

# Register test user
curl -s -X POST http://localhost/api/users/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "datatest@example.com",
    "password": "TestPass123!",
    "name": "Data Test User"
  }' > /dev/null

# Login to get token
TOKEN=$(curl -s -X POST http://localhost/api/users/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "datatest@example.com",
    "password": "TestPass123!"
  }' | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo "❌ Failed to get authentication token"
  exit 1
fi

echo "✅ Authentication successful"

# Test adding ticker with decimal values
echo "Adding AAPL with 10.5 shares at $150.75..."
RESPONSE=$(curl -s -X POST http://localhost/api/portfolio/tickers \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "symbol": "AAPL",
    "shares": 10.5,
    "purchasePrice": 150.75
  }')

echo "Response: $RESPONSE"

# Get portfolio to verify data types
echo "Fetching portfolio data..."
PORTFOLIO=$(curl -s http://localhost/api/portfolio/tickers \
  -H "Authorization: Bearer $TOKEN")

echo "Portfolio Response: $PORTFOLIO"

# Test buy with decimal values
echo "Buying 2.25 more shares..."
BUY_RESPONSE=$(curl -s -X POST http://localhost/api/portfolio/tickers/AAPL/buy \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "shares": 2.25,
    "price": 155.50
  }')

echo "Buy Response: $BUY_RESPONSE"

echo "✅ Data type test completed"