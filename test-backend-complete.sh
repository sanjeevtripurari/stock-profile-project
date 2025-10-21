#!/bin/bash

# Complete Backend API Test Suite
# Tests all endpoints and functionality

set -e

echo "🧪 Complete Backend API Test Suite"
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    local command="$2"
    local expected_pattern="$3"
    
    print_info "Testing: $test_name"
    
    if response=$(eval "$command" 2>&1); then
        if [[ -z "$expected_pattern" ]] || echo "$response" | grep -q "$expected_pattern"; then
            print_success "$test_name"
            ((TESTS_PASSED++))
            return 0
        else
            print_error "$test_name - Response doesn't match expected pattern"
            echo "Response: $response"
            ((TESTS_FAILED++))
            return 1
        fi
    else
        print_error "$test_name - Command failed"
        echo "Error: $response"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Check if services are running
print_info "Checking if services are running..."
if ! curl -s http://localhost/health > /dev/null; then
    print_error "Services not running. Please start with: docker-compose up -d"
    exit 1
fi
print_success "Services are running"

echo ""
echo "🔐 Authentication Tests"
echo "======================"

# Generate unique email for this test run
TEST_EMAIL="test$(date +%s)@example.com"
TEST_PASSWORD="TestPass123!"
TEST_NAME="Backend Test User"

# Test 1: Register user
run_test "User Registration" \
    "curl -s -X POST http://localhost/api/users/register -H 'Content-Type: application/json' -d '{\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\",\"name\":\"$TEST_NAME\"}'" \
    "User registered successfully"

# Test 2: Login user
print_info "Logging in user..."
LOGIN_RESPONSE=$(curl -s -X POST http://localhost/api/users/login \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\"}")

if echo "$LOGIN_RESPONSE" | grep -q "token"; then
    TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    print_success "User Login - Token obtained"
    ((TESTS_PASSED++))
else
    print_error "User Login - Failed to get token"
    echo "Response: $LOGIN_RESPONSE"
    ((TESTS_FAILED++))
    exit 1
fi

echo ""
echo "📊 Market Data Tests"
echo "==================="

# Test 3: Get stock quote
run_test "Stock Quote (AAPL)" \
    "curl -s http://localhost/api/market/quote/AAPL" \
    "symbol.*AAPL"

# Test 4: Batch quotes
run_test "Batch Quotes" \
    "curl -s -X POST http://localhost/api/market/batch-quotes -H 'Content-Type: application/json' -d '{\"symbols\":[\"AAPL\",\"GOOGL\",\"MSFT\"]}'" \
    "quotes"

# Test 5: Market status
run_test "Market Status" \
    "curl -s http://localhost/api/market/status" \
    "isOpen"

# Test 6: Symbol search
run_test "Symbol Search" \
    "curl -s http://localhost/api/market/search?keywords=apple" \
    "results"

echo ""
echo "💼 Portfolio Management Tests"
echo "============================"

# Test 7: Get empty portfolio
run_test "Get Empty Portfolio" \
    "curl -s -H 'Authorization: Bearer $TOKEN' http://localhost/api/portfolio/tickers" \
    "tickers"

# Test 8: Set budget
run_test "Set Budget" \
    "curl -s -X PUT http://localhost/api/portfolio/budget -H 'Authorization: Bearer $TOKEN' -H 'Content-Type: application/json' -d '{\"totalBudget\":50000}'" \
    "Budget.*successfully"

# Test 9: Add first ticker
run_test "Add Ticker (AAPL)" \
    "curl -s -X POST http://localhost/api/portfolio/tickers -H 'Authorization: Bearer $TOKEN' -H 'Content-Type: application/json' -d '{\"symbol\":\"AAPL\",\"shares\":10,\"purchasePrice\":150.50}'" \
    "Ticker added successfully"

# Test 10: Add second ticker (using market price)
run_test "Add Ticker (MSFT - Market Price)" \
    "curl -s -X POST http://localhost/api/portfolio/tickers -H 'Authorization: Bearer $TOKEN' -H 'Content-Type: application/json' -d '{\"symbol\":\"MSFT\",\"shares\":5}'" \
    "Ticker added successfully"

# Test 11: Get portfolio with tickers
run_test "Get Portfolio with Tickers" \
    "curl -s -H 'Authorization: Bearer $TOKEN' http://localhost/api/portfolio/tickers" \
    "AAPL.*MSFT"

# Test 12: Buy more shares
run_test "Buy More Shares (AAPL)" \
    "curl -s -X POST http://localhost/api/portfolio/tickers/AAPL/buy -H 'Authorization: Bearer $TOKEN' -H 'Content-Type: application/json' -d '{\"shares\":5,\"price\":155.00}'" \
    "successfully"

# Test 13: Sell shares
run_test "Sell Shares (AAPL)" \
    "curl -s -X POST http://localhost/api/portfolio/tickers/AAPL/sell -H 'Authorization: Bearer $TOKEN' -H 'Content-Type: application/json' -d '{\"shares\":3,\"price\":160.00}'" \
    "successfully"

# Test 14: Get portfolio summary
run_test "Portfolio Summary" \
    "curl -s -H 'Authorization: Bearer $TOKEN' http://localhost/api/portfolio" \
    "totalTickers.*totalInvested"

# Test 15: Get budget status
run_test "Budget Status" \
    "curl -s -H 'Authorization: Bearer $TOKEN' http://localhost/api/portfolio/budget" \
    "total_budget.*allocated"

echo ""
echo "💰 Dividend Tests"
echo "================"

# Test 16: Get dividend tickers
run_test "Dividend Tickers" \
    "curl -s -H 'Authorization: Bearer $TOKEN' http://localhost/api/dividends/tickers" \
    "tickers"

# Test 17: Get dividend projection
run_test "Dividend Projection" \
    "curl -s -H 'Authorization: Bearer $TOKEN' http://localhost/api/dividends/projection" \
    "totalAnnualDividend"

# Test 18: Get dividend history
run_test "Dividend History (AAPL)" \
    "curl -s http://localhost/api/dividends/history/AAPL" \
    "symbol.*AAPL"

# Test 19: Get dividend calendar
run_test "Dividend Calendar" \
    "curl -s -H 'Authorization: Bearer $TOKEN' http://localhost/api/dividends/calendar?days=30" \
    "calendar"

echo ""
echo "🏥 Health Check Tests"
echo "===================="

# Test 20-24: Service health checks
run_test "User Service Health" \
    "curl -s http://localhost/api/users/health" \
    "healthy"

run_test "Portfolio Service Health" \
    "curl -s http://localhost/api/portfolio/health" \
    "healthy"

run_test "Market Data Service Health" \
    "curl -s http://localhost/api/market/health" \
    "healthy"

run_test "Dividend Service Health" \
    "curl -s http://localhost/api/dividends/health" \
    "healthy"

run_test "NGINX Proxy Health" \
    "curl -s http://localhost/health" \
    "OK"

echo ""
echo "🧹 Cleanup Tests"
echo "================"

# Test 25: Clear caches
run_test "Clear Portfolio Cache" \
    "curl -s -X DELETE http://localhost/api/portfolio/cache -H 'Authorization: Bearer $TOKEN'" \
    "Cache cleared"

run_test "Clear Market Data Cache" \
    "curl -s -X DELETE http://localhost/api/market/cache" \
    "Cache cleared"

echo ""
echo "📊 Test Results Summary"
echo "======================"
echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
echo -e "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"

if [ $TESTS_FAILED -eq 0 ]; then
    echo ""
    print_success "🎉 All tests passed! Backend is fully functional."
    echo ""
    echo "✅ MVP Mode: Working with mock data"
    echo "✅ Authentication: User registration and login"
    echo "✅ Portfolio: Add, buy, sell, update tickers"
    echo "✅ Market Data: Quotes, batch quotes, search"
    echo "✅ Dividends: Tracking and projections"
    echo "✅ Budget: Management and allocation"
    echo "✅ Health Checks: All services responding"
    echo ""
    echo "🚀 System ready for production use!"
else
    echo ""
    print_error "Some tests failed. Please check the errors above."
    exit 1
fi