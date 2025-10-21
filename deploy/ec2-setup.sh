#!/bin/bash
# deploy/ec2-setup.sh
# Complete EC2 instance setup script for Stock Portfolio System

set -e

echo "================================================"
echo "Stock Portfolio System - EC2 Setup"
echo "================================================"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    print_error "Please do not run this script as root"
    exit 1
fi

# Update system
print_info "Updating system packages..."
sudo apt update
sudo apt upgrade -y

# Install essential tools
print_info "Installing essential tools..."
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    vim \
    htop \
    net-tools \
    unzip \
    bc

# Install Docker
print_info "Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    print_info "Docker installed successfully"
else
    print_warn "Docker already installed"
fi

# Install Docker Compose
print_info "Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    print_info "Docker Compose installed successfully"
else
    print_warn "Docker Compose already installed"
fi

# Install Node.js (for local development/testing)
print_info "Installing Node.js..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt install -y nodejs
    print_info "Node.js installed successfully"
else
    print_warn "Node.js already installed"
fi

# Install AWS CLI (optional but recommended)
print_info "Installing AWS CLI..."
if ! command -v aws &> /dev/null; then
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
    print_info "AWS CLI installed successfully"
else
    print_warn "AWS CLI already installed"
fi

# Configure firewall (UFW)
print_info "Configuring firewall..."
sudo ufw --force enable
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
print_info "Firewall configured"

# Create application directory
print_info "Creating application directory..."
mkdir -p ~/stock-profile-project
mkdir -p ~/stock-profile-project/backups
mkdir -p ~/stock-profile-project/logs

# Create systemd service for automatic startup
print_info "Creating systemd service..."
sudo tee /etc/systemd/system/stock-portfolio.service > /dev/null <<EOF
[Unit]
Description=Stock Portfolio Management System
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/$USER/stock-portfolio
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
User=$USER
Group=docker

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable stock-portfolio.service
print_info "Systemd service created and enabled"

# Setup log rotation
print_info "Setting up log rotation..."
sudo tee /etc/logrotate.d/stock-portfolio > /dev/null <<EOF
/home/$USER/stock-portfolio/logs/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 0640 $USER $USER
    sharedscripts
    postrotate
        docker-compose -f /home/$USER/stock-portfolio/docker-compose.yml restart > /dev/null 2>&1 || true
    endscript
}
EOF
print_info "Log rotation configured"

# Create monitoring script
print_info "Creating monitoring scripts..."
cat > ~/stock-profile-project/monitor.sh <<'MONITOREOF'
#!/bin/bash
# Quick monitoring script

echo "==================================="
echo "System Status: $(date)"
echo "==================================="
echo ""

echo "Disk Usage:"
df -h | grep -E '^/dev/'
echo ""

echo "Memory Usage:"
free -h
echo ""

echo "Docker Containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

echo "Service Health:"
curl -s http://localhost/health 2>/dev/null && echo "✓ NGINX Proxy" || echo "✗ NGINX Proxy"
curl -s http://localhost/api/users/health 2>/dev/null && echo "✓ User Service" || echo "✗ User Service"
curl -s http://localhost/api/portfolio/health 2>/dev/null && echo "✓ Portfolio Service" || echo "✗ Portfolio Service"
curl -s http://localhost/api/market/health 2>/dev/null && echo "✓ Market Data Service" || echo "✗ Market Data Service"
curl -s http://localhost/api/dividends/health 2>/dev/null && echo "✓ Dividend Service" || echo "✗ Dividend Service"
MONITOREOF

chmod +x ~/stock-profile-project/monitor.sh

# Create backup script
cat > ~/stock-profile-project/backup.sh <<'BACKUPEOF'
#!/bin/bash
# Automated backup script

BACKUP_DIR="./backups"
DATE=$(date +%Y%m%d_%H%M%S)

echo "Starting backup at $(date)"

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Backup database
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
BACKUPEOF

chmod +x ~/stock-profile-project/backup.sh

# Setup cron jobs
print_info "Setting up cron jobs..."
(crontab -l 2>/dev/null; echo "# Stock Portfolio System Cron Jobs") | crontab -
(crontab -l 2>/dev/null; echo "0 2 * * * /home/$USER/stock-portfolio/backup.sh >> /home/$USER/stock-portfolio/logs/backup.log 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "0 * * * * /home/$USER/stock-portfolio/deploy/health-check.sh >> /home/$USER/stock-portfolio/logs/health.log 2>&1") | crontab -

# Print versions
echo ""
print_info "Installation complete! Versions:"
echo "  Docker: $(docker --version)"
echo "  Docker Compose: $(docker-compose --version)"
echo "  Node.js: $(node --version)"
echo "  NPM: $(npm --version)"
echo ""

print_warn "IMPORTANT: You need to log out and log back in for Docker group changes to take effect!"
echo ""
print_info "Next steps:"
echo "  1. Log out and log back in"
echo "  2. Clone your repository: git clone https://github.com/sanjeevtripurari/stock-profile-project.git ~/stock-profile-project"
echo "  3. Create .env file with your configuration"
echo "  4. Run: cd ~/stock-profile-project && ./deploy/base-setup.sh"
echo "  5. Deploy services: make start"
echo ""
print_info "Useful commands:"
echo "  - Monitor system: ~/stock-profile-project/monitor.sh"
echo "  - Manual backup: ~/stock-profile-project/backup.sh"
echo "  - View logs: make logs"
echo "  - Check health: make health"
echo ""
print_info "Setup completed successfully! 🎉"