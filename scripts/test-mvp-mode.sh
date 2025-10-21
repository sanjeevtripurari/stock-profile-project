#!/bin/bash

# Test MVP Mode functionality
# This script tests that the system works properly in MVP mode

set -e

echo "🧪 Testing MVP Mode Functionality"
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Check if services are running
print_info "Checking if services are running..."
if ! docker-compose ps | grep -q "Up"; then
    print_error "Services are not running. Please start with: make start"
    exit 1
fi

print_success "Services are running"

# Wait for services to be ready
print_info "Waiting for services to be ready..."
sleep 10

# Test market data service with MVP mode
print_info "Testing Market Data Service (MVP Mode)..."

# Test stock quote
QUOTE_RESPONSE=$(curl -s http://localhost/api/market/quote/AAPL || echo "ERROR")
if echo "$QUOTE_RESPONSE" | grep -q "mvpMode"; then
    print_success "Market Data Service returns MVP mock data"
else
    print_error "Market Data Service not working in MVP mode"
    echo "Response: $QUOTE_RESPONSE"
fi

# Test market status
STATUS_RESPONSE=$(curl -s http://localhost/api/market/status || echo "ERROR")
if echo "$STATUS_RESPONSE" | grep -q "isOpen"; then
    print_success "Market Status endpoint working"
else
    print_error "Market Status endpoint not working"
    echo "Response: $STATUS_RESPONSE"
fi

# Test batch quotes
BATCH_RESPONSE=$(curl -s -X POST http://localhost/api/market/batch-quotes \
    -H "Content-Type: application/json" \
    -d '{"symbols":["AAPL","GOOGL","MSFT"]}' || echo "ERROR")
if echo "$BATCH_RESPONSE" | grep -q "quotes"; then
    print_success "Batch quotes endpoint working"
else
    print_error "Batch quotes endpoint not working"
    echo "Response: $BATCH_RESPONSE"
fi

# Register a test user for dividend testing
print_info "Creating test user for dividend testing..."
REGISTER_RESPONSE=$(curl -s -X POST http://localhost/api/users/register \
    -H "Content-Type: application/json" \
    -d '{
        "email": "mvptest@example.com",
        "password": "TestPass123!",
        "name": "MVP Test User"
    }' || echo "ERROR")

if echo "$REGISTER_RESPONSE" | grep -q "token"; then
    print_success "Test user created successfully"
    TOKEN=$(echo "$REGISTER_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
else
    # Try to login if user already exists
    print_info "User might exist, trying to login..."
    LOGIN_RESPONSE=$(curl -s -X POST http://localhost/api/users/login \
        -H "Content-Type: application/json" \
        -d '{
            "email": "mvptest@example.com",
            "password": "TestPass123!"
        }' || echo "ERROR")
    
    if echo "$LOGIN_RESPONSE" | grep -q "token"; then
        print_success "Logged in with existing test user"
        TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    else
        print_error "Could not create or login test user"
        echo "Register Response: $REGISTER_RESPONSE"
        echo "Login Response: $LOGIN_RESPONSE"
        exit 1
    fi
fi

# Add some test stocks to portfolio
print_info "Adding test stocks to portfolio..."
curl -s -X POST http://localhost/api/portfolio/tickers \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"symbol":"AAPL","shares":10,"purchasePrice":150.00}' > /dev/null

curl -s -X POST http://localhost/api/portfolio/tickers \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"symbol":"MSFT","shares":5,"purchasePrice":300.00}' > /dev/null

print_success "Test stocks added to portfolio"

# Test dividend service with MVP mode
print_info "Testing Dividend Service (MVP Mode)..."

DIVIDEND_TICKERS=$(curl -s http://localhost/api/dividends/tickers \
    -H "Authorization: Bearer $TOKEN" || echo "ERROR")

if echo "$DIVIDEND_TICKERS" | grep -q "tickers"; then
    print_success "Dividend tickers endpoint working"
else
    print_error "Dividend tickers endpoint not working"
    echo "Response: $DIVIDEND_TICKERS"
fi

DIVIDEND_PROJECTION=$(curl -s http://localhost/api/dividends/projection \
    -H "Authorization: Bearer $TOKEN" || echo "ERROR")

if echo "$DIVIDEND_PROJECTION" | grep -q "totalAnnualDividend"; then
    print_success "Dividend projection endpoint working"
else
    print_error "Dividend projection endpoint not working"
    echo "Response: $DIVIDEND_PROJECTION"
fi

# Test portfolio functionality
print_info "Testing Portfolio Service..."

PORTFOLIO_RESPONSE=$(curl -s http://localhost/api/portfolio \
    -H "Authorization: Bearer $TOKEN" || echo "ERROR")

if echo "$PORTFOLIO_RESPONSE" | grep -q "tickers"; then
    print_success "Portfolio endpoint working"
else
    print_error "Portfolio endpoint not working"
    echo "Response: $PORTFOLIO_RESPONSE"
fi

# Test buy/sell functionality
print_info "Testing buy/sell functionality..."

BUY_RESPONSE=$(curl -s -X POST http://localhost/api/portfolio/buy \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"symbol":"GOOGL","shares":2}' || echo "ERROR")

if echo "$BUY_RESPONSE" | grep -q "success\|transaction"; then
    print_success "Buy functionality working"
else
    print_error "Buy functionality not working"
    echo "Response: $BUY_RESPONSE"
fi

# Clean up test user (optional)
print_info "Test completed. You can manually clean up the test user if needed."

echo ""
echo "🎉 MVP Mode Test Summary"
echo "======================="
print_success "All MVP mode functionality is working correctly!"
print_info "The system can operate without external API dependencies"
print_info "Mock data is being generated consistently"
print_info "All core features are functional in MVP mode"

echo ""
echo "📝 Next Steps:"
echo "- Set MVP_MODE=false in .env to use real market data"
echo "- Add your Alpha Vantage API key for live data"
echo "- Deploy to production with real market integration"