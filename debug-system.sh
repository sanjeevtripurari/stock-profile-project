#!/bin/bash
# debug-system.sh - Quick system debugging and troubleshooting

set -e

echo "🔍 Stock Portfolio System Debug Report"
echo "====================================="

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

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# 1. Check Docker services
echo ""
echo "1. 🐳 Docker Services Status"
echo "=========================="
if docker-compose ps | grep -q "Up"; then
    print_success "Docker services are running"
    docker-compose ps
else
    print_error "Docker services not running. Run: docker-compose up -d"
    exit 1
fi

# 2. Health checks
echo ""
echo "2. 🏥 Service Health Checks"
echo "=========================="

health_check() {
    local service_name="$1"
    local url="$2"
    
    if curl -s "$url" | grep -q "healthy\|OK"; then
        print_success "$service_name"
    else
        print_error "$service_name"
    fi
}

health_check "NGINX Proxy" "http://localhost/health"
health_check "User Service" "http://localhost/api/users/health"
health_check "Portfolio Service" "http://localhost/api/portfolio/health"
health_check "Market Data Service" "http://localhost/api/market/health"
health_check "Dividend Service" "http://localhost/api/dividends/health"

# 3. MVP Mode check
echo ""
echo "3. 🎯 MVP Mode Configuration"
echo "=========================="
if grep -q "MVP_MODE=true" .env; then
    print_success "MVP Mode Enabled (using mock data)"
else
    print_warning "MVP Mode Disabled (requires Alpha Vantage API)"
fi

# 4. Database connectivity
echo ""
echo "4. 🗄️  Database Status"
echo "==================="
if docker logs stock-portfolio-postgres 2>&1 | grep -q "database system is ready"; then
    print_success "PostgreSQL Database"
else
    print_error "PostgreSQL Database"
fi

if docker logs stock-portfolio-redis 2>&1 | grep -q "Ready to accept connections"; then
    print_success "Redis Cache"
else
    print_error "Redis Cache"
fi

# 5. Quick API functionality test
echo ""
echo "5. 🧪 Quick API Functionality Test"
echo "================================="

# Generate unique email for this test
TEST_EMAIL="debug$(date +%s)@example.com"

print_info "Testing with user: $TEST_EMAIL"

# Register test user
REGISTER_RESPONSE=$(curl -s -X POST http://localhost/api/users/register \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$TEST_EMAIL\",\"password\":\"TestPass123!\",\"name\":\"Debug User\"}")

if echo "$REGISTER_RESPONSE" | grep -q "successfully"; then
    print_success "User Registration"
    
    # Login and get token
    TOKEN=$(curl -s -X POST http://localhost/api/users/login \
      -H "Content-Type: application/json" \
      -d "{\"email\":\"$TEST_EMAIL\",\"password\":\"TestPass123!\"}" | \
      grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    
    if [ ! -z "$TOKEN" ]; then
        print_success "User Login"
        print_info "Token: ${TOKEN:0:20}..."
        
        # Test market data
        MARKET_RESPONSE=$(curl -s http://localhost/api/market/quote/AAPL)
        if echo "$MARKET_RESPONSE" | grep -q "AAPL"; then
            PRICE=$(echo "$MARKET_RESPONSE" | grep -o '"price":[0-9.]*' | cut -d':' -f2)
            print_success "Market Data (AAPL: \$$PRICE)"
        else
            print_error "Market Data"
        fi
        
        # Add test ticker
        ADD_RESPONSE=$(curl -s -X POST http://localhost/api/portfolio/tickers \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d '{"symbol":"AAPL","shares":10,"purchasePrice":150.50}')
        
        if echo "$ADD_RESPONSE" | grep -q "successfully"; then
            print_success "Add Ticker to Portfolio"
            
            # Check portfolio
            PORTFOLIO_RESPONSE=$(curl -s -H "Authorization: Bearer $TOKEN" \
              http://localhost/api/portfolio/tickers)
            
            TICKER_COUNT=$(echo "$PORTFOLIO_RESPONSE" | grep -o '"symbol":"[^"]*"' | wc -l)
            if [ "$TICKER_COUNT" -gt 0 ]; then
                print_success "Portfolio Retrieval ($TICKER_COUNT tickers)"
            else
                print_error "Portfolio Empty"
            fi
            
            # Test dividend projection
            DIVIDEND_RESPONSE=$(curl -s -H "Authorization: Bearer $TOKEN" \
              http://localhost/api/dividends/projection)
            
            ANNUAL_DIVIDEND=$(echo "$DIVIDEND_RESPONSE" | grep -o '"totalAnnualDividend":[0-9.]*' | cut -d':' -f2)
            if [ ! -z "$ANNUAL_DIVIDEND" ] && [ "$ANNUAL_DIVIDEND" != "0" ]; then
                print_success "Dividend Calculation (\$$ANNUAL_DIVIDEND annual)"
            else
                print_error "Dividend Calculation (showing \$0)"
                print_info "Try clearing dividend cache: curl -X DELETE -H 'Authorization: Bearer $TOKEN' http://localhost/api/dividends/cache"
            fi
            
            # Test buy/sell functionality
            BUY_RESPONSE=$(curl -s -X POST http://localhost/api/portfolio/tickers/AAPL/buy \
              -H "Authorization: Bearer $TOKEN" \
              -H "Content-Type: application/json" \
              -d '{"shares":5,"price":155.00}')
            
            if echo "$BUY_RESPONSE" | grep -q "successfully"; then
                print_success "Buy Shares Functionality"
            else
                print_error "Buy Shares Functionality"
            fi
            
        else
            print_error "Add Ticker to Portfolio"
            echo "Response: $ADD_RESPONSE"
        fi
    else
        print_error "User Login - No token received"
        echo "Response: $REGISTER_RESPONSE"
    fi
else
    print_error "User Registration"
    echo "Response: $REGISTER_RESPONSE"
fi

# 6. Frontend check
echo ""
echo "6. 🌐 Frontend Status"
echo "=================="

FRONTEND_RESPONSE=$(curl -s http://localhost/)
if echo "$FRONTEND_RESPONSE" | grep -q "Stock Portfolio Manager"; then
    print_success "Frontend HTML Loading"
    
    # Check if JavaScript is being served
    JS_FILE=$(echo "$FRONTEND_RESPONSE" | grep -o '/static/js/main\.[^"]*\.js' | head -1)
    if [ ! -z "$JS_FILE" ]; then
        if curl -s "http://localhost$JS_FILE" | grep -q "React"; then
            print_success "Frontend JavaScript Loading"
        else
            print_warning "Frontend JavaScript may have issues"
        fi
    fi
else
    print_error "Frontend Not Loading"
fi

# 7. Common issues and solutions
echo ""
echo "7. 🔧 Common Issues & Solutions"
echo "=============================="

echo "If you see issues above, try these solutions:"
echo ""
echo "📋 Portfolio showing empty:"
echo "   curl -X DELETE -H 'Authorization: Bearer \$TOKEN' http://localhost/api/portfolio/cache"
echo ""
echo "💰 Dividends showing \$0:"
echo "   curl -X DELETE -H 'Authorization: Bearer \$TOKEN' http://localhost/api/dividends/cache"
echo ""
echo "🔄 Services not responding:"
echo "   docker-compose restart"
echo ""
echo "🧹 Complete reset:"
echo "   docker-compose down -v && docker-compose up -d"
echo ""
echo "📊 Run complete backend tests:"
echo "   make test-backend"
echo ""

# 8. Summary
echo ""
echo "8. 📊 Debug Summary"
echo "=================="

if docker-compose ps | grep -q "Up.*healthy"; then
    print_success "System Status: All services running and healthy"
    echo ""
    echo "🚀 System is ready for use!"
    echo "   Frontend: http://localhost/"
    echo "   API: http://localhost/api/"
    echo ""
    echo "📖 For more debugging commands, see README.md"
else
    print_warning "System Status: Some services may have issues"
    echo ""
    echo "🔍 Check the issues above and run suggested solutions"
fi

echo ""
echo "Debug completed at $(date)"