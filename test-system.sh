#!/bin/bash
# test-system.sh
# Quick system test

echo "🧪 Testing Stock Portfolio System"
echo "================================="
echo ""

# Test health endpoints
echo "1. Testing Health Endpoints:"
curl -s http://localhost/health && echo " ✅ NGINX Proxy" || echo " ❌ NGINX Proxy"
curl -s http://localhost/api/users/health && echo " ✅ User Service" || echo " ❌ User Service"
curl -s http://localhost/api/portfolio/health && echo " ✅ Portfolio Service" || echo " ❌ Portfolio Service"
curl -s http://localhost/api/market/health && echo " ✅ Market Data Service" || echo " ❌ Market Data Service"
curl -s http://localhost/api/dividends/health && echo " ✅ Dividend Service" || echo " ❌ Dividend Service"

echo ""
echo "2. Testing Market Status:"
curl -s http://localhost/api/market/status | head -c 100
echo ""

echo ""
echo "3. Testing Frontend:"
if curl -s http://localhost/ | grep -q "Stock Portfolio"; then
    echo " ✅ Frontend loading"
else
    echo " ❌ Frontend not loading"
fi

echo ""
echo "4. Container Status:"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep stock-portfolio

echo ""
echo "✅ Test completed!"