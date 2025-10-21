#!/bin/bash
# scripts/backup.sh
# Database backup script

set -e

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

BACKUP_DIR="./backups"
DATE=$(date +%Y%m%d_%H%M%S)

echo "================================================"
echo "Stock Portfolio System - Backup"
echo "Started at: $(date)"
echo "================================================"
echo ""

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Check if containers are running
if ! docker ps | grep -q stock-portfolio-postgres; then
    print_error "PostgreSQL container is not running"
    exit 1
fi

if ! docker ps | grep -q stock-portfolio-redis; then
    print_warn "Redis container is not running, skipping Redis backup"
    SKIP_REDIS=true
fi

# Backup PostgreSQL
print_info "Backing up PostgreSQL database..."
docker exec stock-portfolio-postgres pg_dump -U stockuser stockportfolio > \
    $BACKUP_DIR/db_backup_$DATE.sql

if [ $? -eq 0 ]; then
    print_info "✓ PostgreSQL backup completed"
    
    # Compress the backup
    gzip $BACKUP_DIR/db_backup_$DATE.sql
    print_info "✓ PostgreSQL backup compressed"
    
    # Get file size
    BACKUP_SIZE=$(du -h $BACKUP_DIR/db_backup_$DATE.sql.gz | cut -f1)
    print_info "✓ Backup size: $BACKUP_SIZE"
else
    print_error "✗ PostgreSQL backup failed"
    exit 1
fi

# Backup Redis (if running)
if [ "$SKIP_REDIS" != "true" ]; then
    print_info "Backing up Redis data..."
    
    # Trigger background save
    docker exec stock-portfolio-redis redis-cli BGSAVE
    
    # Wait for background save to complete
    print_info "Waiting for Redis background save to complete..."
    sleep 5
    
    # Copy the dump file
    docker cp stock-portfolio-redis:/data/dump.rdb $BACKUP_DIR/redis_backup_$DATE.rdb
    
    if [ $? -eq 0 ]; then
        print_info "✓ Redis backup completed"
        
        # Compress the backup
        gzip $BACKUP_DIR/redis_backup_$DATE.rdb
        print_info "✓ Redis backup compressed"
        
        # Get file size
        REDIS_SIZE=$(du -h $BACKUP_DIR/redis_backup_$DATE.rdb.gz | cut -f1)
        print_info "✓ Redis backup size: $REDIS_SIZE"
    else
        print_warn "✗ Redis backup failed (non-critical)"
    fi
fi

# Backup configuration files
print_info "Backing up configuration files..."
tar -czf $BACKUP_DIR/config_backup_$DATE.tar.gz \
    .env docker-compose.yml nginx/ deploy/ scripts/ \
    --exclude=deploy/*.log --exclude=scripts/*.log 2>/dev/null

if [ $? -eq 0 ]; then
    print_info "✓ Configuration backup completed"
    CONFIG_SIZE=$(du -h $BACKUP_DIR/config_backup_$DATE.tar.gz | cut -f1)
    print_info "✓ Configuration backup size: $CONFIG_SIZE"
else
    print_warn "✗ Configuration backup failed (non-critical)"
fi

# Clean up old backups (keep last 30 days)
print_info "Cleaning up old backups (keeping last 30 days)..."
OLD_BACKUPS=$(find $BACKUP_DIR -name "*.gz" -mtime +30 | wc -l)
if [ $OLD_BACKUPS -gt 0 ]; then
    find $BACKUP_DIR -name "*.gz" -mtime +30 -delete
    print_info "✓ Removed $OLD_BACKUPS old backup files"
else
    print_info "✓ No old backups to remove"
fi

# Generate backup report
print_info "Generating backup report..."
cat > $BACKUP_DIR/backup_report_$DATE.txt << EOF
Stock Portfolio System - Backup Report
======================================
Date: $(date)
Backup ID: $DATE

Files Created:
- db_backup_$DATE.sql.gz (PostgreSQL)
$([ "$SKIP_REDIS" != "true" ] && echo "- redis_backup_$DATE.rdb.gz (Redis)")
- config_backup_$DATE.tar.gz (Configuration)

Backup Directory: $BACKUP_DIR
Total Backups: $(ls -1 $BACKUP_DIR/*.gz 2>/dev/null | wc -l)
Directory Size: $(du -sh $BACKUP_DIR | cut -f1)

System Status at Backup Time:
$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep stock-portfolio)

Database Statistics:
$(docker exec stock-portfolio-postgres psql -U stockuser -d stockportfolio -c "
SELECT 
    schemaname,
    tablename,
    n_tup_ins as inserts,
    n_tup_upd as updates,
    n_tup_del as deletes
FROM pg_stat_user_tables 
ORDER BY schemaname, tablename;" 2>/dev/null || echo "Could not retrieve database statistics")
EOF

echo ""
print_info "🎉 Backup completed successfully!"
echo ""
print_info "Backup Summary:"
echo "  - Database: ✓ Backed up and compressed"
$([ "$SKIP_REDIS" != "true" ] && echo "  - Redis: ✓ Backed up and compressed")
echo "  - Configuration: ✓ Backed up and compressed"
echo "  - Report: backup_report_$DATE.txt"
echo ""
print_info "Files created in $BACKUP_DIR/:"
ls -la $BACKUP_DIR/*$DATE* 2>/dev/null || echo "No files found"
echo ""
print_info "To restore from this backup:"
echo "  Database: gunzip -c $BACKUP_DIR/db_backup_$DATE.sql.gz | docker exec -i stock-portfolio-postgres psql -U stockuser -d stockportfolio"
$([ "$SKIP_REDIS" != "true" ] && echo "  Redis: gunzip -c $BACKUP_DIR/redis_backup_$DATE.rdb.gz > dump.rdb && docker cp dump.rdb stock-portfolio-redis:/data/")
echo ""
print_info "Backup completed at: $(date)"