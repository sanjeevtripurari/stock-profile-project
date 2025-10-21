#!/bin/bash
# deploy/base-setup.sh
# Setup base infrastructure for Stock Portfolio System

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

echo "================================================"
echo "Stock Portfolio System - Base Infrastructure Setup"
echo "================================================"
echo ""

# Check if .env file exists
if [ ! -f .env ]; then
    print_error ".env file not found!"
    print_info "Please copy .env.example to .env and configure your values:"
    print_info "  cp .env.example .env"
    print_info "  nano .env"
    exit 1
fi

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if Docker Compose is available
if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose is not installed. Please install it and try again."
    exit 1
fi

# Load environment variables
source .env

# Validate required environment variables
print_step "Validating environment variables..."

required_vars=(
    "POSTGRES_PASSWORD"
    "REDIS_PASSWORD"
    "JWT_SECRET"
    "ALPHA_VANTAGE_API_KEY"
)

missing_vars=()
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ] || [ "${!var}" = "CHANGE_ME" ] || [ "${!var}" = "YOUR_API_KEY_HERE" ]; then
        missing_vars+=("$var")
    fi
done

if [ ${#missing_vars[@]} -ne 0 ]; then
    print_error "Missing or invalid environment variables:"
    for var in "${missing_vars[@]}"; do
        echo "  - $var"
    done
    print_info "Please update your .env file with proper values."
    exit 1
fi

print_info "Environment variables validated ✓"

# Create necessary directories
print_step "Creating directories..."
mkdir -p logs backups ssl
print_info "Directories created ✓"

# Create Docker network
print_step "Creating Docker network..."
if ! docker network ls | grep -q stock-network; then
    docker network create stock-network
    print_info "Docker network 'stock-network' created ✓"
else
    print_warn "Docker network 'stock-network' already exists"
fi

# Pull required images
print_step "Pulling Docker images..."
docker-compose pull postgres redis
print_info "Base images pulled ✓"

# Start PostgreSQL and Redis first
print_step "Starting PostgreSQL and Redis..."
docker-compose up -d postgres redis

# Wait for PostgreSQL to be ready
print_info "Waiting for PostgreSQL to be ready..."
timeout=60
counter=0
while ! docker exec stock-portfolio-postgres pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB} > /dev/null 2>&1; do
    if [ $counter -ge $timeout ]; then
        print_error "PostgreSQL failed to start within $timeout seconds"
        docker logs stock-portfolio-postgres
        exit 1
    fi
    sleep 2
    counter=$((counter + 2))
    echo -n "."
done
echo ""
print_info "PostgreSQL is ready ✓"

# Wait for Redis to be ready
print_info "Waiting for Redis to be ready..."
timeout=30
counter=0
while ! docker exec stock-portfolio-redis redis-cli -a ${REDIS_PASSWORD} ping > /dev/null 2>&1; do
    if [ $counter -ge $timeout ]; then
        print_error "Redis failed to start within $timeout seconds"
        docker logs stock-portfolio-redis
        exit 1
    fi
    sleep 1
    counter=$((counter + 1))
    echo -n "."
done
echo ""
print_info "Redis is ready ✓"

# Verify database initialization
print_step "Verifying database initialization..."
table_count=$(docker exec stock-portfolio-postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" | tr -d ' ')

if [ "$table_count" -ge 5 ]; then
    print_info "Database tables created successfully ✓ ($table_count tables)"
else
    print_error "Database initialization may have failed. Only $table_count tables found."
    print_info "Expected at least 5 tables (users, portfolio, budget, dividend_history, user_sessions)"
fi

# Create backup script
print_step "Creating backup script..."
cat > scripts/backup.sh << 'EOF'
#!/bin/bash
# Automated backup script

BACKUP_DIR="./backups"
DATE=$(date +%Y%m%d_%H%M%S)

echo "Starting backup at $(date)"

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Backup PostgreSQL
echo "Backing up PostgreSQL..."
docker exec stock-portfolio-postgres pg_dump -U stockuser stockportfolio > \
    $BACKUP_DIR/db_backup_$DATE.sql

if [ $? -eq 0 ]; then
    echo "✓ PostgreSQL backup completed"
    gzip $BACKUP_DIR/db_backup_$DATE.sql
    echo "✓ PostgreSQL backup compressed"
else
    echo "✗ PostgreSQL backup failed"
    exit 1
fi

# Backup Redis
echo "Backing up Redis..."
docker exec stock-portfolio-redis redis-cli BGSAVE
sleep 5
docker cp stock-portfolio-redis:/data/dump.rdb $BACKUP_DIR/redis_backup_$DATE.rdb

if [ $? -eq 0 ]; then
    echo "✓ Redis backup completed"
    gzip $BACKUP_DIR/redis_backup_$DATE.rdb
    echo "✓ Redis backup compressed"
else
    echo "✗ Redis backup failed"
fi

# Remove backups older than 30 days
echo "Cleaning old backups..."
find $BACKUP_DIR -name "*.gz" -mtime +30 -delete
echo "✓ Old backups cleaned"

echo "Backup completed at $(date)"
echo "Files created:"
ls -la $BACKUP_DIR/*$DATE*
EOF

chmod +x scripts/backup.sh
print_info "Backup script created ✓"

# Test backup
print_step "Testing backup functionality..."
./scripts/backup.sh
if [ $? -eq 0 ]; then
    print_info "Backup test successful ✓"
else
    print_warn "Backup test failed, but continuing..."
fi

# Create monitoring script
print_step "Creating monitoring script..."
cat > scripts/monitor.sh << 'EOF'
#!/bin/bash
# System monitoring script

echo "==================================="
echo "Stock Portfolio System Monitor"
echo "Time: $(date)"
echo "==================================="
echo ""

echo "🐳 Docker Containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep stock-portfolio
echo ""

echo "💾 Disk Usage:"
df -h | grep -E '^/dev/'
echo ""

echo "🧠 Memory Usage:"
free -h
echo ""

echo "📊 Container Resources:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep stock-portfolio
echo ""

echo "🏥 Service Health:"
services=("users" "portfolio" "market" "dividends")
for service in "${services[@]}"; do
    if curl -s http://localhost/api/$service/health > /dev/null 2>&1; then
        echo "✅ $service service: healthy"
    else
        echo "❌ $service service: unhealthy"
    fi
done

# Check NGINX
if curl -s http://localhost/health > /dev/null 2>&1; then
    echo "✅ NGINX proxy: healthy"
else
    echo "❌ NGINX proxy: unhealthy"
fi

echo ""
echo "📝 Recent Errors (last 5 minutes):"
docker logs --since 5m stock-portfolio-nginx-proxy 2>&1 | grep -i error | tail -3 || echo "No recent errors"
EOF

chmod +x scripts/monitor.sh
print_info "Monitoring script created ✓"

# Create NGINX stats script
print_step "Creating NGINX statistics script..."
cat > scripts/nginx-stats.sh << 'EOF'
#!/bin/bash
# NGINX statistics script

echo "📊 NGINX Access Statistics"
echo "=========================="
echo ""

if ! docker exec stock-portfolio-nginx-proxy test -f /var/log/nginx/access.log 2>/dev/null; then
    echo "No access logs found yet. Start using the application to generate logs."
    exit 0
fi

echo "Top 10 Requested URLs:"
docker exec stock-portfolio-nginx-proxy cat /var/log/nginx/access.log 2>/dev/null | \
    awk '{print $7}' | sort | uniq -c | sort -rn | head -10
echo ""

echo "HTTP Status Codes:"
docker exec stock-portfolio-nginx-proxy cat /var/log/nginx/access.log 2>/dev/null | \
    awk '{print $9}' | sort | uniq -c | sort -rn
echo ""

echo "Top 10 IP Addresses:"
docker exec stock-portfolio-nginx-proxy cat /var/log/nginx/access.log 2>/dev/null | \
    awk '{print $1}' | sort | uniq -c | sort -rn | head -10
echo ""

echo "Request Methods:"
docker exec stock-portfolio-nginx-proxy cat /var/log/nginx/access.log 2>/dev/null | \
    awk '{print $6}' | sort | uniq -c
EOF

chmod +x scripts/nginx-stats.sh
print_info "NGINX statistics script created ✓"

echo ""
print_info "🎉 Base infrastructure setup completed successfully!"
echo ""
print_info "Next steps:"
echo "  1. Start all services: make start"
echo "  2. Check health: make health"
echo "  3. Access application: http://localhost/"
echo ""
print_info "Useful commands:"
echo "  - View logs: make logs"
echo "  - Monitor system: make monitor"
echo "  - Backup data: make backup"
echo "  - Deploy service: make deploy-<service>"
echo ""
print_warn "Note: Make sure to configure your .env file with proper values before starting services!"