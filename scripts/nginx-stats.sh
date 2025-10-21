#!/bin/bash
# scripts/nginx-stats.sh
# NGINX access statistics and analytics

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}$1${NC}"
}

echo "================================================"
echo "NGINX Access Statistics & Analytics"
echo "Generated: $(date)"
echo "================================================"
echo ""

# Check if NGINX container is running
if ! docker ps | grep -q stock-portfolio-nginx-proxy; then
    echo -e "${RED}❌ NGINX proxy container is not running${NC}"
    exit 1
fi

# Check if access log exists
if ! docker exec stock-portfolio-nginx-proxy test -f /var/log/nginx/access.log 2>/dev/null; then
    echo -e "${YELLOW}⚠️  No access logs found yet. Start using the application to generate logs.${NC}"
    exit 0
fi

# Get log file size and line count
log_size=$(docker exec stock-portfolio-nginx-proxy du -h /var/log/nginx/access.log 2>/dev/null | cut -f1)
log_lines=$(docker exec stock-portfolio-nginx-proxy wc -l /var/log/nginx/access.log 2>/dev/null | cut -d' ' -f1)

echo "📊 Log File Info:"
echo "  Size: $log_size"
echo "  Total requests: $log_lines"
echo ""

# Top 10 requested URLs
print_header "🔗 Top 10 Requested URLs"
docker exec stock-portfolio-nginx-proxy cat /var/log/nginx/access.log 2>/dev/null | \
    awk '{print $7}' | sort | uniq -c | sort -rn | head -10 | \
    while read count url; do
        printf "  %6s  %s\n" "$count" "$url"
    done
echo ""

# HTTP Status Code Distribution
print_header "📈 HTTP Status Code Distribution"
docker exec stock-portfolio-nginx-proxy cat /var/log/nginx/access.log 2>/dev/null | \
    awk '{print $9}' | sort | uniq -c | sort -rn | \
    while read count status; do
        case $status in
            2*) color=$GREEN ;;
            3*) color=$YELLOW ;;
            4*|5*) color=$RED ;;
            *) color=$NC ;;
        esac
        printf "  ${color}%6s  %s${NC}\n" "$count" "$status"
    done
echo ""

# Top 10 IP Addresses
print_header "🌍 Top 10 Client IP Addresses"
docker exec stock-portfolio-nginx-proxy cat /var/log/nginx/access.log 2>/dev/null | \
    awk '{print $1}' | sort | uniq -c | sort -rn | head -10 | \
    while read count ip; do
        printf "  %6s  %s\n" "$count" "$ip"
    done
echo ""

# Request Methods Distribution
print_header "🔄 HTTP Methods Distribution"
docker exec stock-portfolio-nginx-proxy cat /var/log/nginx/access.log 2>/dev/null | \
    awk '{print $6}' | sed 's/"//g' | sort | uniq -c | sort -rn | \
    while read count method; do
        printf "  %6s  %s\n" "$count" "$method"
    done
echo ""

# Hourly Request Distribution (last 24 hours)
print_header "⏰ Hourly Request Distribution (Last 24 Hours)"
docker exec stock-portfolio-nginx-proxy cat /var/log/nginx/access.log 2>/dev/null | \
    awk '{print $4}' | sed 's/\[//g' | cut -d: -f2 | sort | uniq -c | \
    while read count hour; do
        printf "  %02d:00  " "$hour"
        # Create simple bar chart
        bar_length=$((count / 10))
        if [ $bar_length -gt 50 ]; then bar_length=50; fi
        for i in $(seq 1 $bar_length); do printf "█"; done
        printf " (%s)\n" "$count"
    done
echo ""

# Response Time Analysis
print_header "⚡ Response Time Analysis"
if docker exec stock-portfolio-nginx-proxy cat /var/log/nginx/access.log 2>/dev/null | grep -q "rt="; then
    echo "Response Time Statistics:"
    
    # Extract response times and calculate statistics
    response_times=$(docker exec stock-portfolio-nginx-proxy cat /var/log/nginx/access.log 2>/dev/null | \
        grep -o 'rt=[0-9.]*' | cut -d= -f2 | head -1000)
    
    if [ ! -z "$response_times" ]; then
        # Calculate average response time
        avg_time=$(echo "$response_times" | awk '{sum+=$1; count++} END {printf "%.3f", sum/count}')
        echo "  Average: ${avg_time}s"
        
        # Find min and max
        min_time=$(echo "$response_times" | sort -n | head -1)
        max_time=$(echo "$response_times" | sort -n | tail -1)
        echo "  Min: ${min_time}s"
        echo "  Max: ${max_time}s"
        
        # Calculate 95th percentile
        percentile_95=$(echo "$response_times" | sort -n | awk 'BEGIN{c=0} {a[c++]=$1} END{print a[int(c*0.95)]}')
        echo "  95th percentile: ${percentile_95}s"
    fi
else
    echo "  Response time data not available in current log format"
fi
echo ""

# API Endpoint Usage
print_header "🔌 API Endpoint Usage"
docker exec stock-portfolio-nginx-proxy cat /var/log/nginx/access.log 2>/dev/null | \
    grep "/api/" | awk '{print $7}' | sed 's/\?.*$//' | sort | uniq -c | sort -rn | head -10 | \
    while read count endpoint; do
        printf "  %6s  %s\n" "$count" "$endpoint"
    done
echo ""

# Error Analysis
print_header "🚨 Error Analysis (4xx and 5xx)"
error_count=$(docker exec stock-portfolio-nginx-proxy cat /var/log/nginx/access.log 2>/dev/null | \
    awk '$9 >= 400 {print $0}' | wc -l)

if [ $error_count -gt 0 ]; then
    echo "Total errors: $error_count"
    echo ""
    echo "Error breakdown:"
    docker exec stock-portfolio-nginx-proxy cat /var/log/nginx/access.log 2>/dev/null | \
        awk '$9 >= 400 {print $9, $7}' | sort | uniq -c | sort -rn | head -10 | \
        while read count status url; do
            case $status in
                4*) color=$YELLOW ;;
                5*) color=$RED ;;
                *) color=$NC ;;
            esac
            printf "  ${color}%6s  %s  %s${NC}\n" "$count" "$status" "$url"
        done
else
    echo -e "${GREEN}✅ No errors found in access logs${NC}"
fi
echo ""

# User Agent Analysis
print_header "🌐 Top User Agents"
docker exec stock-portfolio-nginx-proxy cat /var/log/nginx/access.log 2>/dev/null | \
    awk -F'"' '{print $6}' | sort | uniq -c | sort -rn | head -5 | \
    while read count agent; do
        # Truncate long user agent strings
        short_agent=$(echo "$agent" | cut -c1-60)
        if [ ${#agent} -gt 60 ]; then
            short_agent="${short_agent}..."
        fi
        printf "  %6s  %s\n" "$count" "$short_agent"
    done
echo ""

# Cache Performance (if available)
print_header "💾 Cache Performance"
if docker exec stock-portfolio-nginx-proxy cat /var/log/nginx/access.log 2>/dev/null | grep -q "HIT\|MISS"; then
    cache_hits=$(docker exec stock-portfolio-nginx-proxy cat /var/log/nginx/access.log 2>/dev/null | grep -c "HIT")
    cache_misses=$(docker exec stock-portfolio-nginx-proxy cat /var/log/nginx/access.log 2>/dev/null | grep -c "MISS")
    total_cached_requests=$((cache_hits + cache_misses))
    
    if [ $total_cached_requests -gt 0 ]; then
        hit_rate=$(echo "scale=2; $cache_hits * 100 / $total_cached_requests" | bc)
        echo "  Cache hits: $cache_hits"
        echo "  Cache misses: $cache_misses"
        echo "  Hit rate: ${hit_rate}%"
    fi
else
    echo "  Cache statistics not available"
fi
echo ""

# Bandwidth Usage
print_header "📊 Bandwidth Usage"
total_bytes=$(docker exec stock-portfolio-nginx-proxy cat /var/log/nginx/access.log 2>/dev/null | \
    awk '{sum+=$10} END {print sum}')

if [ ! -z "$total_bytes" ] && [ "$total_bytes" != "0" ]; then
    # Convert bytes to human readable format
    if [ $total_bytes -gt 1073741824 ]; then
        bandwidth=$(echo "scale=2; $total_bytes / 1073741824" | bc)
        echo "  Total bandwidth: ${bandwidth} GB"
    elif [ $total_bytes -gt 1048576 ]; then
        bandwidth=$(echo "scale=2; $total_bytes / 1048576" | bc)
        echo "  Total bandwidth: ${bandwidth} MB"
    else
        bandwidth=$(echo "scale=2; $total_bytes / 1024" | bc)
        echo "  Total bandwidth: ${bandwidth} KB"
    fi
    
    # Average per request
    if [ $log_lines -gt 0 ]; then
        avg_bytes=$(echo "scale=0; $total_bytes / $log_lines" | bc)
        echo "  Average per request: ${avg_bytes} bytes"
    fi
else
    echo "  Bandwidth data not available"
fi
echo ""

# Recent Activity (last hour)
print_header "🕐 Recent Activity (Last Hour)"
recent_requests=$(docker exec stock-portfolio-nginx-proxy cat /var/log/nginx/access.log 2>/dev/null | \
    awk -v since="$(date -d '1 hour ago' '+%d/%b/%Y:%H:%M:%S')" '$4 > "["since {count++} END {print count+0}')

echo "  Requests in last hour: $recent_requests"

if [ $recent_requests -gt 0 ]; then
    echo "  Recent status codes:"
    docker exec stock-portfolio-nginx-proxy cat /var/log/nginx/access.log 2>/dev/null | \
        awk -v since="$(date -d '1 hour ago' '+%d/%b/%Y:%H:%M:%S')" '$4 > "["since {print $9}' | \
        sort | uniq -c | sort -rn | head -5 | \
        while read count status; do
            printf "    %s: %s\n" "$status" "$count"
        done
fi
echo ""

# Recommendations
print_header "💡 Recommendations"

# Check for high error rates
error_rate=$(echo "scale=2; $error_count * 100 / $log_lines" | bc 2>/dev/null || echo "0")
if [ $(echo "$error_rate > 5" | bc 2>/dev/null || echo "0") -eq 1 ]; then
    echo -e "  ${RED}⚠️  High error rate (${error_rate}%) - investigate 4xx/5xx responses${NC}"
fi

# Check for slow responses
if [ ! -z "$avg_time" ] && [ $(echo "$avg_time > 1.0" | bc 2>/dev/null || echo "0") -eq 1 ]; then
    echo -e "  ${YELLOW}⚠️  Slow average response time (${avg_time}s) - consider optimization${NC}"
fi

# Check for cache efficiency
if [ ! -z "$hit_rate" ] && [ $(echo "$hit_rate < 70" | bc 2>/dev/null || echo "0") -eq 1 ]; then
    echo -e "  ${YELLOW}⚠️  Low cache hit rate (${hit_rate}%) - review cache configuration${NC}"
fi

# Check for suspicious activity
suspicious_ips=$(docker exec stock-portfolio-nginx-proxy cat /var/log/nginx/access.log 2>/dev/null | \
    awk '$9 >= 400 {print $1}' | sort | uniq -c | awk '$1 > 50 {print $2}' | wc -l)

if [ $suspicious_ips -gt 0 ]; then
    echo -e "  ${RED}⚠️  ${suspicious_ips} IP(s) with high error rates - potential security concern${NC}"
fi

if [ $error_count -eq 0 ] && [ $(echo "${avg_time:-0} < 0.5" | bc 2>/dev/null || echo "1") -eq 1 ]; then
    echo -e "  ${GREEN}✅ System performing well - no issues detected${NC}"
fi

echo ""
echo "================================================"
echo "Statistics generated at: $(date)"
echo "================================================"