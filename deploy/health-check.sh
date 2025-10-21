#!/bin/bash
# deploy/health-check.sh
# Health check script for all services

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    local service=$1
    local status=$2
    local url=$3
    
    if [ "$status" = "healthy" ] || [ "$status" = "reachable" ] || [[ "$status" == *"enabled"* ]]; then
        echo -e "✅ ${GREEN}$service${NC}: $status"
    else
        echo -e "❌ ${RED}$service${NC}: $status"
        if [ ! -z "$url" ]; then
            echo -e "   ${YELLOW}URL: $url${NC}"
        fi
    fi
}

echo "================================================"
echo "Stock Portfolio System - Health Check"
echo "================================================"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running${NC}"
    exit 1
fi

echo -e "${BLUE}🐳 Container Status:${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep stock-portfolio || echo "No containers running"
echo ""

echo -e "${BLUE}🏥 Service Health Checks:${NC}"

# Check NGINX Proxy (main entry point)
if curl -s -f http://localhost/health > /dev/null 2>&1; then
    print_status "NGINX Proxy" "healthy" "http://localhost/health"
    nginx_healthy=true
else
    print_status "NGINX Proxy" "unhealthy" "http://localhost/health"
    nginx_healthy=false
fi

# Check unified API health endpoint
if curl -s -f http://localhost/api/health > /dev/null 2>&1; then
    print_status "API Gateway" "healthy" "http://localhost/api/health"
else
    print_status "API Gateway" "unhealthy" "http://localhost/api/health"
    all_healthy=false
fi

# Check individual services through NGINX proxy
services=("users" "portfolio" "market" "dividends")
all_healthy=true

for service in "${services[@]}"; do
    url="http://localhost/api/$service/health"
    if curl -s -f "$url" > /dev/null 2>&1; then
        print_status "$service Service" "healthy" "$url"
    else
        print_status "$service Service" "unhealthy" "$url"
        all_healthy=false
    fi
done

echo ""

# Check database connectivity
echo -e "${BLUE}💾 Database Health:${NC}"
if docker exec stock-portfolio-postgres pg_isready -U stockuser -d stockportfolio > /dev/null 2>&1; then
    print_status "PostgreSQL" "healthy"
else
    print_status "PostgreSQL" "unhealthy"
    all_healthy=false
fi

# Check Redis connectivity
if docker exec stock-portfolio-redis redis-cli -a "${REDIS_PASSWORD:-}" ping > /dev/null 2>&1; then
    print_status "Redis" "healthy"
else
    print_status "Redis" "unhealthy"
    all_healthy=false
fi

echo ""

# Check frontend
echo -e "${BLUE}🌐 Frontend Health:${NC}"
if curl -s -f http://localhost/ > /dev/null 2>&1; then
    print_status "Frontend" "healthy" "http://localhost/"
else
    print_status "Frontend" "unhealthy" "http://localhost/"
    all_healthy=false
fi

echo ""

# Resource usage
echo -e "${BLUE}📊 Resource Usage:${NC}"
echo "Disk Usage:"
df -h | grep -E '^/dev/' | head -3

echo ""
echo "Memory Usage:"
free -h

echo ""
echo "Container Resources:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep stock-portfolio | head -10

echo ""

# Network connectivity test
echo -e "${BLUE}🌐 Network Connectivity:${NC}"

# Check MVP mode first
if grep -q "MVP_MODE=true" .env 2>/dev/null; then
    print_status "MVP Mode" "enabled (using mock data)"
    echo -e "   ${BLUE}ℹ️  External API connectivity not required in MVP mode${NC}"
else
    if curl -s -f https://www.alphavantage.co > /dev/null 2>&1; then
        print_status "Alpha Vantage API" "reachable"
    else
        print_status "Alpha Vantage API" "unreachable"
        echo -e "   ${YELLOW}Warning: Market data may not work without MVP mode${NC}"
        all_healthy=false
    fi
fi

echo ""

# Summary
echo "================================================"
if [ "$all_healthy" = true ] && [ "$nginx_healthy" = true ]; then
    echo -e "${GREEN}🎉 All services are healthy!${NC}"
    echo ""
    echo -e "${BLUE}Access your application:${NC}"
    echo "  Frontend: http://localhost/"
    echo "  API: http://localhost/api/"
    echo ""
    echo -e "${BLUE}Quick test commands:${NC}"
    echo "  curl http://localhost/health"
    echo "  curl http://localhost/api/users/health"
    echo "  curl http://localhost/api/portfolio/health"
    exit 0
else
    echo -e "${RED}❌ Some services are unhealthy${NC}"
    echo ""
    echo -e "${YELLOW}Troubleshooting steps:${NC}"
    echo "  1. Check logs: make logs"
    echo "  2. Restart services: make restart"
    echo "  3. Check .env configuration"
    echo "  4. Verify Docker resources"
    echo ""
    echo -e "${YELLOW}Common fixes:${NC}"
    echo "  - docker-compose restart <service-name>"
    echo "  - docker-compose down && docker-compose up -d"
    echo "  - Check firewall settings"
    echo "  - Verify environment variables"
    exit 1
fi