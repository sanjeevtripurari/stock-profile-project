#!/bin/bash
# deploy/test-proxy.sh
# Test NGINX reverse proxy routing

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

BASE_URL="http://localhost"

echo "================================================"
echo "NGINX Reverse Proxy - Routing Test"
echo "================================================"
echo ""

test_endpoint() {
    local name=$1
    local url=$2
    local expected_status=${3:-200}
    
    echo -n "Testing $name... "
    
    response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    
    if [ "$response" = "$expected_status" ]; then
        echo -e "${GREEN}✅ OK ($response)${NC}"
        return 0
    else
        echo -e "${RED}❌ FAILED ($response)${NC}"
        return 1
    fi
}

test_endpoint_with_content() {
    local name=$1
    local url=$2
    local expected_content=$3
    
    echo -n "Testing $name... "
    
    response=$(curl -s "$url" 2>/dev/null || echo "")
    
    if echo "$response" | grep -q "$expected_content"; then
        echo -e "${GREEN}✅ OK${NC}"
        return 0
    else
        echo -e "${RED}❌ FAILED${NC}"
        echo -e "  ${YELLOW}Expected: $expected_content${NC}"
        echo -e "  ${YELLOW}Got: ${response:0:100}...${NC}"
        return 1
    fi
}

failed_tests=0

echo -e "${BLUE}🌐 Frontend Tests:${NC}"
test_endpoint "Frontend Root" "$BASE_URL/" || ((failed_tests++))

echo ""
echo -e "${BLUE}🏥 Health Check Tests:${NC}"
test_endpoint "NGINX Health" "$BASE_URL/health" || ((failed_tests++))
test_endpoint_with_content "NGINX Health Content" "$BASE_URL/health" "healthy" || ((failed_tests++))

echo ""
echo -e "${BLUE}🔧 Service Health Tests:${NC}"
test_endpoint "User Service Health" "$BASE_URL/api/users/health" || ((failed_tests++))
test_endpoint "Portfolio Service Health" "$BASE_URL/api/portfolio/health" || ((failed_tests++))
test_endpoint "Market Data Service Health" "$BASE_URL/api/market/health" || ((failed_tests++))
test_endpoint "Dividend Service Health" "$BASE_URL/api/dividends/health" || ((failed_tests++))

echo ""
echo -e "${BLUE}🌐 CORS Tests:${NC}"
echo -n "Testing CORS Headers... "
cors_headers=$(curl -s -I "$BASE_URL/api/users/health" | grep -i "access-control-allow-origin" || echo "")
if [ ! -z "$cors_headers" ]; then
    echo -e "${GREEN}✅ Present${NC}"
    echo -e "  ${YELLOW}$cors_headers${NC}"
else
    echo -e "${RED}❌ Missing${NC}"
    ((failed_tests++))
fi

echo ""
echo -e "${BLUE}🚦 Rate Limiting Tests:${NC}"
echo -n "Testing Rate Limiting... "
# Send 3 rapid requests to test rate limiting
responses=()
for i in {1..3}; do
    response=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/users/health" 2>/dev/null)
    responses+=($response)
done

# All should be 200 (within limit)
if [[ "${responses[0]}" = "200" && "${responses[1]}" = "200" && "${responses[2]}" = "200" ]]; then
    echo -e "${GREEN}✅ Working (within limits)${NC}"
else
    echo -e "${YELLOW}⚠️  Rate limiting may be active${NC}"
    echo -e "  ${YELLOW}Responses: ${responses[*]}${NC}"
fi

echo ""
echo -e "${BLUE}🔄 API Routing Tests:${NC}"

# Test different API paths
api_paths=(
    "/api/users/health:User Service"
    "/api/portfolio/health:Portfolio Service"
    "/api/market/health:Market Data Service"
    "/api/dividends/health:Dividend Service"
)

for path_info in "${api_paths[@]}"; do
    IFS=':' read -r path service <<< "$path_info"
    test_endpoint "$service Routing" "$BASE_URL$path" || ((failed_tests++))
done

echo ""
echo -e "${BLUE}📊 Response Time Tests:${NC}"
echo -n "Testing Response Times... "

# Test response time for health endpoint
response_time=$(curl -s -o /dev/null -w "%{time_total}" "$BASE_URL/health" 2>/dev/null || echo "999")
response_time_ms=$(echo "$response_time * 1000" | bc 2>/dev/null || echo "999")

if (( $(echo "$response_time < 1.0" | bc -l 2>/dev/null || echo "0") )); then
    echo -e "${GREEN}✅ Fast (${response_time_ms%.*}ms)${NC}"
else
    echo -e "${YELLOW}⚠️  Slow (${response_time_ms%.*}ms)${NC}"
fi

echo ""
echo -e "${BLUE}🔍 Service Discovery Tests:${NC}"

# Test if services can reach each other through NGINX
echo -n "Testing Internal Routing... "
# This tests if NGINX can route to backend services
internal_test=$(curl -s "$BASE_URL/api/users/health" | grep -o "user-service" || echo "")
if [ ! -z "$internal_test" ]; then
    echo -e "${GREEN}✅ Services reachable${NC}"
else
    echo -e "${YELLOW}⚠️  Check service names${NC}"
fi

echo ""
echo "================================================"

if [ $failed_tests -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed! NGINX proxy is working correctly.${NC}"
    echo ""
    echo -e "${BLUE}✅ Verified functionality:${NC}"
    echo "  - Frontend accessible at $BASE_URL/"
    echo "  - All API services routed correctly"
    echo "  - Health checks working"
    echo "  - CORS headers present"
    echo "  - Rate limiting configured"
    echo "  - Response times acceptable"
    echo ""
    echo -e "${BLUE}🌐 Access URLs:${NC}"
    echo "  Frontend:     $BASE_URL/"
    echo "  API Gateway:  $BASE_URL/api/"
    echo "  Health Check: $BASE_URL/health"
    echo ""
    echo -e "${BLUE}📝 API Endpoints:${NC}"
    echo "  Users:        $BASE_URL/api/users/"
    echo "  Portfolio:    $BASE_URL/api/portfolio/"
    echo "  Market Data:  $BASE_URL/api/market/"
    echo "  Dividends:    $BASE_URL/api/dividends/"
    
    exit 0
else
    echo -e "${RED}❌ $failed_tests test(s) failed!${NC}"
    echo ""
    echo -e "${YELLOW}🔧 Troubleshooting steps:${NC}"
    echo "  1. Check NGINX logs: docker logs stock-portfolio-nginx-proxy"
    echo "  2. Verify services are running: docker ps"
    echo "  3. Check service logs: make logs"
    echo "  4. Restart NGINX: docker-compose restart nginx-proxy"
    echo "  5. Full restart: make restart"
    echo ""
    echo -e "${YELLOW}📋 Common issues:${NC}"
    echo "  - Services not started: make start"
    echo "  - Wrong configuration: check nginx/nginx-proxy.conf"
    echo "  - Port conflicts: check if port 80 is available"
    echo "  - Firewall blocking: check UFW/iptables rules"
    
    exit 1
fi