#!/bin/bash
# deploy/setup-ssl.sh
# Setup SSL certificates with Let's Encrypt

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Check if domain is provided
if [ -z "$1" ]; then
    print_error "Usage: $0 <domain-name>"
    echo ""
    echo "Example: $0 myportfolio.com"
    exit 1
fi

DOMAIN=$1

echo "================================================"
echo "Setting up SSL for: $DOMAIN"
echo "================================================"
echo ""

# Check if running on EC2/server
if [ ! -f /etc/os-release ]; then
    print_error "This script should be run on a Linux server"
    exit 1
fi

# Check if domain points to this server
print_step "Checking DNS configuration..."
SERVER_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip)
DOMAIN_IP=$(dig +short $DOMAIN | tail -n1)

if [ "$SERVER_IP" != "$DOMAIN_IP" ]; then
    print_warn "Domain $DOMAIN does not point to this server ($SERVER_IP)"
    print_warn "Domain currently points to: $DOMAIN_IP"
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Install certbot
print_step "Installing certbot..."
if ! command -v certbot &> /dev/null; then
    sudo apt update
    sudo apt install -y certbot python3-certbot-nginx
    print_info "Certbot installed successfully"
else
    print_warn "Certbot already installed"
fi

# Stop NGINX temporarily
print_step "Stopping NGINX proxy..."
docker-compose stop nginx-proxy

# Get SSL certificate
print_step "Obtaining SSL certificate..."
sudo certbot certonly --standalone \
    --preferred-challenges http \
    --email admin@$DOMAIN \
    --agree-tos \
    --no-eff-email \
    -d $DOMAIN

if [ $? -ne 0 ]; then
    print_error "Failed to obtain SSL certificate"
    print_info "Starting NGINX proxy again..."
    docker-compose start nginx-proxy
    exit 1
fi

# Create SSL directory
print_step "Setting up SSL files..."
mkdir -p ssl

# Copy certificates
sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem ssl/
sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem ssl/
sudo chown $USER:$USER ssl/*.pem

print_info "SSL certificates copied to ./ssl/"

# Update NGINX configuration for HTTPS
print_step "Updating NGINX configuration..."

# Backup original config
cp nginx/nginx-proxy.conf nginx/nginx-proxy.conf.backup

# Create HTTPS configuration
cat > nginx/nginx-proxy-ssl.conf << EOF
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    # Logging format
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for" '
                    'rt=\$request_time uct="\$upstream_connect_time" '
                    'uht="\$upstream_header_time" urt="\$upstream_response_time"';

    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log warn;

    # Basic settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 10M;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;

    # Rate limiting zones
    limit_req_zone \$binary_remote_addr zone=api_limit:10m rate=100r/m;
    limit_req_zone \$binary_remote_addr zone=login_limit:10m rate=5r/m;

    # Cache settings for market data
    proxy_cache_path /var/cache/nginx/market 
        levels=1:2 
        keys_zone=market_cache:10m 
        max_size=100m 
        inactive=10m;

    # Upstream services
    upstream user_service {
        server user-service:3001;
        keepalive 32;
    }

    upstream portfolio_service {
        server portfolio-service:3002;
        keepalive 32;
    }

    upstream market_data_service {
        server market-data-service:3003;
        keepalive 32;
    }

    upstream dividend_service {
        server dividend-service:3004;
        keepalive 32;
    }

    upstream frontend_service {
        server frontend:80;
        keepalive 32;
    }

    # Redirect HTTP to HTTPS
    server {
        listen 80;
        server_name $DOMAIN;
        return 301 https://\$server_name\$request_uri;
    }

    # HTTPS server
    server {
        listen 443 ssl http2;
        server_name $DOMAIN;

        # SSL configuration
        ssl_certificate /etc/nginx/ssl/fullchain.pem;
        ssl_certificate_key /etc/nginx/ssl/privkey.pem;
        
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
        ssl_prefer_server_ciphers off;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;
        
        # HSTS
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;

        # CORS headers
        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'Authorization, Content-Type, X-Requested-With' always;
        add_header 'Access-Control-Max-Age' '86400' always;

        # Handle preflight requests
        if (\$request_method = 'OPTIONS') {
            add_header 'Access-Control-Allow-Origin' '*';
            add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS';
            add_header 'Access-Control-Allow-Headers' 'Authorization, Content-Type, X-Requested-With';
            add_header 'Access-Control-Max-Age' '86400';
            add_header 'Content-Type' 'text/plain; charset=utf-8';
            add_header 'Content-Length' '0';
            return 204;
        }

        # Health check endpoint
        location = /health {
            access_log off;
            return 200 '{"status":"healthy","service":"nginx-proxy","ssl":true,"timestamp":"\$time_iso8601"}';
            add_header Content-Type application/json;
        }

        # User service routes
        location /api/users {
            if (\$uri ~ "/api/users/login") {
                limit_req zone=login_limit burst=10 nodelay;
            }
            limit_req zone=api_limit burst=20 nodelay;

            proxy_pass http://user_service;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_cache_bypass \$http_upgrade;
            
            proxy_connect_timeout 5s;
            proxy_send_timeout 10s;
            proxy_read_timeout 10s;
        }

        # Portfolio service routes
        location /api/portfolio {
            limit_req zone=api_limit burst=20 nodelay;

            proxy_pass http://portfolio_service;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_cache_bypass \$http_upgrade;
            
            proxy_connect_timeout 5s;
            proxy_send_timeout 10s;
            proxy_read_timeout 10s;
        }

        # Market data service routes (with caching)
        location /api/market {
            limit_req zone=api_limit burst=20 nodelay;

            proxy_cache market_cache;
            proxy_cache_valid 200 5m;
            proxy_cache_valid 404 1m;
            proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;
            proxy_cache_lock on;
            add_header X-Cache-Status \$upstream_cache_status;

            proxy_pass http://market_data_service;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_cache_bypass \$http_upgrade;
            
            proxy_connect_timeout 10s;
            proxy_send_timeout 15s;
            proxy_read_timeout 15s;
        }

        # Dividend service routes
        location /api/dividends {
            limit_req zone=api_limit burst=20 nodelay;

            proxy_pass http://dividend_service;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_cache_bypass \$http_upgrade;
            
            proxy_connect_timeout 10s;
            proxy_send_timeout 15s;
            proxy_read_timeout 15s;
        }

        # Frontend routes
        location / {
            try_files \$uri \$uri/ @frontend;
            
            location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)\$ {
                expires 1y;
                add_header Cache-Control "public, immutable";
                access_log off;
                
                proxy_pass http://frontend_service;
                proxy_http_version 1.1;
                proxy_set_header Host \$host;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto \$scheme;
            }
        }

        location @frontend {
            proxy_pass http://frontend_service;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_cache_bypass \$http_upgrade;
            
            proxy_connect_timeout 5s;
            proxy_send_timeout 10s;
            proxy_read_timeout 10s;
        }

        # Error pages
        error_page 404 /404.html;
        error_page 500 502 503 504 /50x.html;
        
        location = /50x.html {
            root /usr/share/nginx/html;
            internal;
        }
        
        location = /404.html {
            root /usr/share/nginx/html;
            internal;
        }
    }
}
EOF

# Replace the NGINX configuration
mv nginx/nginx-proxy-ssl.conf nginx/nginx-proxy.conf

print_info "NGINX configuration updated for HTTPS"

# Update docker-compose.yml to mount SSL certificates
print_step "Updating Docker Compose configuration..."

# Backup docker-compose.yml
cp docker-compose.yml docker-compose.yml.backup

# Update docker-compose.yml to include SSL volume and port 443
sed -i '/ports:/,/- "80:80"/ {
    /- "80:80"/a\      - "443:443"
}' docker-compose.yml

sed -i '/volumes:/,/- \.\/nginx\/nginx-proxy\.conf/ {
    /- \.\/nginx\/nginx-proxy\.conf/a\      - ./ssl:/etc/nginx/ssl:ro
}' docker-compose.yml

print_info "Docker Compose configuration updated"

# Start NGINX with SSL
print_step "Starting NGINX with SSL..."
docker-compose up -d nginx-proxy

# Wait for NGINX to start
sleep 10

# Test HTTPS
print_step "Testing HTTPS configuration..."
if curl -s -f https://$DOMAIN/health > /dev/null; then
    print_info "✅ HTTPS is working correctly!"
else
    print_error "❌ HTTPS test failed"
    print_info "Check logs: docker logs stock-portfolio-nginx-proxy"
fi

# Setup auto-renewal
print_step "Setting up SSL certificate auto-renewal..."

# Create renewal script
cat > ~/stock-profile-project/renew-ssl.sh << EOF
#!/bin/bash
# SSL certificate renewal script

echo "Checking SSL certificate renewal..."

# Stop NGINX
docker-compose -f /home/$USER/stock-portfolio/docker-compose.yml stop nginx-proxy

# Renew certificate
sudo certbot renew --quiet

# Copy new certificates
sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem /home/$USER/stock-portfolio/ssl/
sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem /home/$USER/stock-portfolio/ssl/
sudo chown $USER:$USER /home/$USER/stock-portfolio/ssl/*.pem

# Start NGINX
docker-compose -f /home/$USER/stock-portfolio/docker-compose.yml start nginx-proxy

echo "SSL renewal check completed"
EOF

chmod +x ~/stock-profile-project/renew-ssl.sh

# Add to cron for automatic renewal
(crontab -l 2>/dev/null; echo "0 3 * * 0 /home/$USER/stock-portfolio/renew-ssl.sh >> /home/$USER/stock-portfolio/logs/ssl-renewal.log 2>&1") | crontab -

print_info "SSL auto-renewal configured (runs weekly)"

echo ""
print_info "🎉 SSL setup completed successfully!"
echo ""
print_info "Your application is now available at:"
echo "  HTTPS: https://$DOMAIN/"
echo "  HTTP:  http://$DOMAIN/ (redirects to HTTPS)"
echo ""
print_info "SSL Certificate Details:"
echo "  Domain: $DOMAIN"
echo "  Issuer: Let's Encrypt"
echo "  Auto-renewal: Enabled (weekly check)"
echo ""
print_info "Files created/modified:"
echo "  - ssl/fullchain.pem"
echo "  - ssl/privkey.pem"
echo "  - nginx/nginx-proxy.conf (updated for HTTPS)"
echo "  - docker-compose.yml (updated with SSL volumes)"
echo "  - renew-ssl.sh (auto-renewal script)"
echo ""
print_warn "Backup files created:"
echo "  - nginx/nginx-proxy.conf.backup"
echo "  - docker-compose.yml.backup"