#!/bin/bash
# scripts/monitor.sh
# System monitoring script

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

clear
echo "================================================"
echo "Stock Portfolio System - System Monitor"
echo "Time: $(date)"
echo "Uptime: $(uptime -p 2>/dev/null || uptime)"
echo "================================================"
echo ""

# System Resources
print_header "💻 System Resources"
echo "Disk Usage:"
df -h | grep -E '^/dev/' | while read line; do
    usage=$(echo $line | awk '{print $5}' | sed 's/%//')
    if [ $usage -gt 90 ]; then
        echo -e "${RED}$line${NC}"
    elif [ $usage -gt 80 ]; then
        echo -e "${YELLOW}$line${NC}"
    else
        echo -e "${GREEN}$line${NC}"
    fi
done

echo ""
echo "Memory Usage:"
free -h | while read line; do
    if echo $line | grep -q "Mem:"; then
        used=$(echo $line | awk '{print $3}')
        total=$(echo $line | awk '{print $2}')
        echo -e "${GREEN}$line${NC}"
    else
        echo "$line"
    fi
done

echo ""
echo "CPU Load:"
load=$(uptime | awk -F'load average:' '{print $2}')
echo "Load Average:$load"

echo ""

# Docker Status
print_header "🐳 Docker Containers"
if docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -q stock-portfolio; then
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep stock-portfolio | while read line; do
        if echo $line | grep -q "Up"; then
            echo -e "${GREEN}$line${NC}"
        else
            echo -e "${RED}$line${NC}"
        fi
    done
else
    print_error "No Stock Portfolio containers found"
fi

echo ""

# Container Resource Usage
print_header "📊 Container Resources"
if docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" | grep -q stock-portfolio; then
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" | grep stock-portfolio
else
    print_error "No container stats available"
fi

echo ""

# Service Health Checks
print_header "🏥 Service Health"

# Check NGINX Proxy
if curl -s -f http://localhost/health > /dev/null 2>&1; then
    print_success "NGINX Proxy"
else
    print_error "NGINX Proxy"
fi

# Check individual services
services=("users" "portfolio" "market" "dividends")
for service in "${services[@]}"; do
    if curl -s -f "http://localhost/api/$service/health" > /dev/null 2>&1; then
        print_success "$service Service"
    else
        print_error "$service Service"
    fi
done

# Check Frontend
if curl -s -f http://localhost/ > /dev/null 2>&1; then
    print_success "Frontend"
else
    print_error "Frontend"
fi

echo ""

# Database Status
print_header "💾 Database Status"

# PostgreSQL
if docker exec stock-portfolio-postgres pg_isready -U stockuser -d stockportfolio > /dev/null 2>&1; then
    print_success "PostgreSQL"
    
    # Get database stats
    db_size=$(docker exec stock-portfolio-postgres psql -U stockuser -d stockportfolio -t -c "SELECT pg_size_pretty(pg_database_size('stockportfolio'));" 2>/dev/null | tr -d ' ')
    if [ ! -z "$db_size" ]; then
        echo "  Database size: $db_size"
    fi
    
    # Get connection count
    connections=$(docker exec stock-portfolio-postgres psql -U stockuser -d stockportfolio -t -c "SELECT count(*) FROM pg_stat_activity WHERE datname='stockportfolio';" 2>/dev/null | tr -d ' ')
    if [ ! -z "$connections" ]; then
        echo "  Active connections: $connections"
    fi
else
    print_error "PostgreSQL"
fi

# Redis
if docker exec stock-portfolio-redis redis-cli ping > /dev/null 2>&1; then
    print_success "Redis"
    
    # Get Redis info
    memory_usage=$(docker exec stock-portfolio-redis redis-cli info memory | grep used_memory_human | cut -d: -f2 | tr -d '\r')
    if [ ! -z "$memory_usage" ]; then
        echo "  Memory usage: $memory_usage"
    fi
    
    # Get key count
    key_count=$(docker exec stock-portfolio-redis redis-cli dbsize 2>/dev/null)
    if [ ! -z "$key_count" ]; then
        echo "  Cached keys: $key_count"
    fi
else
    print_error "Redis"
fi

echo ""

# Network Connectivity
print_header "🌐 Network Connectivity"

# Check external API
if curl -s -f --max-time 5 https://www.alphavantage.co > /dev/null 2>&1; then
    print_success "Alpha Vantage API reachable"
else
    print_warning "Alpha Vantage API unreachable (market data may not work)"
fi

# Check internet connectivity
if ping -c 1 8.8.8.8 > /dev/null 2>&1; then
    print_success "Internet connectivity"
else
    print_error "Internet connectivity"
fi

echo ""

# Recent Errors
print_header "🚨 Recent Errors (last 10 minutes)"
error_count=0

# Check NGINX errors
if docker logs --since 10m stock-portfolio-nginx-proxy 2>&1 | grep -i error | head -3; then
    ((error_count++))
fi

# Check service errors
for service in user-service portfolio-service market-data-service dividend-service; do
    if docker logs --since 10m "stock-portfolio-$service" 2>&1 | grep -i error | head -2; then
        ((error_count++))
    fi
done

if [ $error_count -eq 0 ]; then
    print_success "No recent errors found"
fi

echo ""

# Performance Metrics
print_header "⚡ Performance Metrics"

# Response time test
response_time=$(curl -s -o /dev/null -w "%{time_total}" http://localhost/health 2>/dev/null || echo "N/A")
if [ "$response_time" != "N/A" ]; then
    response_ms=$(echo "$response_time * 1000" | bc 2>/dev/null | cut -d. -f1)
    if [ $response_ms -lt 100 ]; then
        print_success "Response time: ${response_ms}ms (excellent)"
    elif [ $response_ms -lt 500 ]; then
        echo -e "${YELLOW}⚠ Response time: ${response_ms}ms (acceptable)${NC}"
    else
        print_warning "Response time: ${response_ms}ms (slow)"
    fi
else
    print_error "Could not measure response time"
fi

# Check if SSL is enabled
if curl -s -f https://localhost/health > /dev/null 2>&1; then
    print_success "HTTPS enabled"
elif curl -s -f -k https://localhost/health > /dev/null 2>&1; then
    print_warning "HTTPS enabled (self-signed certificate)"
else
    echo "  HTTPS: Not configured"
fi

echo ""

# Backup Status
print_header "💾 Backup Status"
if [ -d "./backups" ]; then
    backup_count=$(ls -1 ./backups/*.gz 2>/dev/null | wc -l)
    if [ $backup_count -gt 0 ]; then
        latest_backup=$(ls -t ./backups/*.gz 2>/dev/null | head -1)
        backup_age=$(stat -c %Y "$latest_backup" 2>/dev/null)
        current_time=$(date +%s)
        age_hours=$(( (current_time - backup_age) / 3600 ))
        
        if [ $age_hours -lt 24 ]; then
            print_success "Latest backup: $age_hours hours ago"
        elif [ $age_hours -lt 168 ]; then  # 7 days
            print_warning "Latest backup: $((age_hours / 24)) days ago"
        else
            print_error "Latest backup: $((age_hours / 24)) days ago (too old)"
        fi
        
        echo "  Total backups: $backup_count"
        backup_size=$(du -sh ./backups 2>/dev/null | cut -f1)
        echo "  Backup directory size: $backup_size"
    else
        print_warning "No backups found"
    fi
else
    print_warning "Backup directory not found"
fi

echo ""

# Quick Actions
print_header "🔧 Quick Actions"
echo "Available commands:"
echo "  make logs          - View all logs"
echo "  make health        - Run health check"
echo "  make backup        - Create backup"
echo "  make restart       - Restart all services"
echo "  ./deploy/test-proxy.sh - Test NGINX routing"

echo ""
echo "================================================"
echo "Monitor completed at: $(date)"
echo "================================================"