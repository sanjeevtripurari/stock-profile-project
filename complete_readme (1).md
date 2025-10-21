# Stock Portfolio Management System - Complete Guide

## Table of Contents
1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Directory Structure](#directory-structure)
4. [Prerequisites](#prerequisites)
5. [Local Development Setup](#local-development-setup)
6. [EC2 Deployment Guide](#ec2-deployment-guide)
7. [Independent Service Deployment](#independent-service-deployment)
8. [Environment Configuration](#environment-configuration)
9. [API Documentation](#api-documentation)
10. [Monitoring & Troubleshooting](#monitoring--troubleshooting)

---

## Project Overview

A microservices-based stock portfolio management system that allows users to:
- Register and manage their accounts
- Select and track stock tickers
- Set investment budgets
- Track real-time stock prices
- Monitor dividend-paying stocks
- Project yearly dividend income

### Key Features
- **Microservices Architecture**: Each service can be deployed independently
- **Scalable**: Add more instances of any service as needed
- **Fault Tolerant**: Service failures don't affect other services
- **Cacheable**: Redis caching for improved performance
- **Real-time Data**: Integration with Alpha Vantage API

---

## Architecture

```
┌─────────────┐
│   Frontend  │ (React + Tailwind)
└──────┬──────┘
       │
┌──────▼──────┐
│ API Gateway │ (NGINX)
└──────┬──────┘
       │
       ├─────────┬─────────────┬──────────────┬───────────────┐
       │         │             │              │               │
┌──────▼──────┐ │      ┌──────▼──────┐ ┌────▼─────┐  ┌─────▼─────┐
│User Service │ │      │  Portfolio  │ │  Market  │  │ Dividend  │
│   :3001     │ │      │  Service    │ │   Data   │  │  Service  │
└──────┬──────┘ │      │   :3002     │ │  :3003   │  │   :3004   │
       │         │      └──────┬──────┘ └────┬─────┘  └─────┬─────┘
       │         │             │             │              │
       └─────────┴─────────────┴─────────────┴──────────────┘
                               │
                 ┌─────────────┴─────────────┐
                 │                           │
           ┌─────▼─────┐              ┌─────▼─────┐
           │PostgreSQL │              │   Redis   │
           │   :5432   │              │   :6379   │
           └───────────┘              └───────────┘
```

### Services Breakdown

1. **User Service** (Port 3001)
   - User registration and authentication
   - JWT token generation and verification
   - Password hashing with bcrypt
   - Session management

2. **Portfolio Service** (Port 3002)
   - Manage user's stock portfolio
   - Add/remove tickers
   - Set and track budgets
   - Calculate allocations

3. **Market Data Service** (Port 3003)
   - Fetch real-time stock prices from Alpha Vantage
   - Cache market data in Redis
   - Batch quote requests
   - Rate limiting handling

4. **Dividend Service** (Port 3004)
   - Track dividend-paying stocks
   - Calculate dividend yields
   - Project annual dividend income
   - Historical dividend data

5. **API Gateway** (Port 3000)
   - Route requests to appropriate services
   - Load balancing
   - Request logging
   - CORS handling

6. **Frontend** (Port 3005)
   - React-based user interface
   - Responsive design with Tailwind CSS
   - User authentication flow
   - Portfolio management dashboard

---

## Directory Structure

```
stock-portfolio/
├── README.md
├── docker-compose.yml
├── .env
├── .env.example
├── init-db.sql
│
├── deploy/
│   ├── base-setup.sh              # Setup base infrastructure
│   ├── deploy-service.sh          # Deploy individual services
│   ├── rollback-service.sh        # Rollback to previous version
│   ├── health-check.sh            # Check all services health
│   └── ec2-setup.sh               # EC2 instance setup script
│
├── user-service/
│   ├── Dockerfile
│   ├── package.json
│   ├── package-lock.json
│   └── src/
│       ├── index.js
│       ├── middleware/
│       │   └── auth.js
│       └── routes/
│           └── users.js
│
├── portfolio-service/
│   ├── Dockerfile
│   ├── package.json
│   ├── package-lock.json
│   └── src/
│       ├── index.js
│       ├── middleware/
│       │   └── auth.js
│       └── routes/
│           └── portfolio.js
│
├── market-data-service/
│   ├── Dockerfile
│   ├── package.json
│   ├── package-lock.json
│   └── src/
│       ├── index.js
│       ├── services/
│       │   └── alphaVantage.js
│       └── routes/
│           └── market.js
│
├── dividend-service/
│   ├── Dockerfile
│   ├── package.json
│   ├── package-lock.json
│   └── src/
│       ├── index.js
│       ├── services/
│       │   ├── dividendCalculator.js
│       │   └── projection.js
│       └── routes/
│           └── dividends.js
│
├── frontend/
│   ├── Dockerfile
│   ├── package.json
│   ├── package-lock.json
│   ├── nginx.conf
│   └── src/
│       ├── App.js
│       ├── index.js
│       ├── components/
│       │   ├── Auth/
│       │   │   ├── Login.js
│       │   │   └── Register.js
│       │   ├── Portfolio/
│       │   │   ├── TickerList.js
│       │   │   ├── AddTicker.js
│       │   │   └── Budget.js
│       │   └── Dividends/
│       │       ├── DividendList.js
│       │       └── Projection.js
│       ├── services/
│       │   └── api.js
│       └── utils/
│           └── auth.js
│
└── nginx/
    ├── Dockerfile
    └── nginx.conf
```

---

## Prerequisites

### Local Development
- Docker 20.10+
- Docker Compose 2.0+
- Git
- Text editor (VS Code recommended)

### EC2 Deployment
- AWS Account
- EC2 instance (t3.medium or higher recommended)
- Ubuntu 22.04 LTS or Amazon Linux 2023
- At least 4GB RAM, 20GB storage
- Security group with required ports open
- SSH key pair for access

### External Services
- Alpha Vantage API Key (free tier: https://www.alphavantage.co/support/#api-key)

---

## Local Development Setup

### Step 1: Clone Repository

```bash
git clone <your-repo-url>
cd stock-portfolio
```

### Step 2: Create Environment File

Copy the example environment file:

```bash
cp .env.example .env
```

Edit `.env` with your values:

```bash
nano .env
# or
vim .env
```

### Step 3: Initialize Base Infrastructure

```bash
chmod +x deploy/*.sh
./deploy/base-setup.sh
```

This will:
- Create Docker network
- Start PostgreSQL database
- Start Redis cache
- Run database migrations
- Start API Gateway

### Step 4: Deploy Services

Deploy all services at once:

```bash
./deploy/deploy-service.sh user-service
./deploy/deploy-service.sh portfolio-service
./deploy/deploy-service.sh market-data-service
./deploy/deploy-service.sh dividend-service
./deploy/deploy-service.sh frontend
```

Or use docker-compose:

```bash
docker-compose up -d
```

### Step 5: Verify Deployment

```bash
./deploy/health-check.sh
```

Access the application:
- Frontend: http://localhost:3005
- API Gateway: http://localhost:3000
- User Service: http://localhost:3001
- Portfolio Service: http://localhost:3002
- Market Data Service: http://localhost:3003
- Dividend Service: http://localhost:3004

---

## EC2 Deployment Guide

### Step 1: Launch EC2 Instance

1. **Login to AWS Console**
2. **Launch EC2 Instance**:
   - AMI: Ubuntu Server 22.04 LTS
   - Instance Type: t3.medium (or higher)
   - Storage: 20GB gp3
   - Security Group: Create new or use existing

3. **Configure Security Group**:
   ```
   SSH:        Port 22    (Source: Your IP)
   HTTP:       Port 80    (Source: 0.0.0.0/0)
   HTTPS:      Port 443   (Source: 0.0.0.0/0)
   Custom:     Port 3000  (Source: 0.0.0.0/0) - API Gateway
   Custom:     Port 3005  (Source: 0.0.0.0/0) - Frontend
   ```

4. **Download Key Pair** (.pem file)

### Step 2: Connect to EC2 Instance

```bash
chmod 400 your-key.pem
ssh -i your-key.pem ubuntu@<EC2-PUBLIC-IP>
```

### Step 3: Run EC2 Setup Script

Create and run the setup script:

```bash
# Download the setup script
curl -o ec2-setup.sh https://raw.githubusercontent.com/<your-repo>/main/deploy/ec2-setup.sh

# Make it executable
chmod +x ec2-setup.sh

# Run setup
./ec2-setup.sh
```

Or manually install dependencies:

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify installations
docker --version
docker-compose --version

# Logout and login again for group changes
exit
```

### Step 4: Clone Repository on EC2

```bash
# Reconnect to EC2
ssh -i your-key.pem ubuntu@<EC2-PUBLIC-IP>

# Clone repository
git clone <your-repo-url>
cd stock-portfolio
```

### Step 5: Configure Environment Variables on EC2

**Option 1: Using .env file**

```bash
nano .env
```

Paste your configuration and save (Ctrl+X, Y, Enter).

**Option 2: Using EC2 Environment Variables (Recommended for production)**

```bash
# Add to ~/.bashrc or ~/.profile
nano ~/.bashrc

# Add at the end:
export POSTGRES_USER=stockuser
export POSTGRES_PASSWORD=your_secure_password
export POSTGRES_DB=stockportfolio
export REDIS_PASSWORD=your_redis_password
export JWT_SECRET=your_jwt_secret_key
export ALPHA_VANTAGE_API_KEY=your_api_key
export USER_SERVICE_PORT=3001
export PORTFOLIO_SERVICE_PORT=3002
export MARKET_DATA_SERVICE_PORT=3003
export DIVIDEND_SERVICE_PORT=3004
export API_GATEWAY_PORT=3000
export FRONTEND_PORT=3005

# Load variables
source ~/.bashrc
```

**Option 3: Using AWS Systems Manager Parameter Store**

```bash
# Install AWS CLI
sudo apt install awscli -y

# Configure AWS CLI
aws configure

# Store parameters
aws ssm put-parameter --name /stock-portfolio/postgres-password --value "your_password" --type SecureString
aws ssm put-parameter --name /stock-portfolio/jwt-secret --value "your_jwt_secret" --type SecureString

# Create script to fetch parameters
cat > load-env.sh << 'EOF'
#!/bin/bash
export POSTGRES_PASSWORD=$(aws ssm get-parameter --name /stock-portfolio/postgres-password --with-decryption --query 'Parameter.Value' --output text)
export JWT_SECRET=$(aws ssm get-parameter --name /stock-portfolio/jwt-secret --with-decryption --query 'Parameter.Value' --output text)
# Add more parameters as needed
EOF

chmod +x load-env.sh
source ./load-env.sh
```

### Step 6: Deploy on EC2

```bash
# Setup base infrastructure
./deploy/base-setup.sh

# Deploy all services
docker-compose up -d

# Or deploy individually
./deploy/deploy-service.sh user-service
./deploy/deploy-service.sh portfolio-service
./deploy/deploy-service.sh market-data-service
./deploy/deploy-service.sh dividend-service
./deploy/deploy-service.sh frontend

# Check health
./deploy/health-check.sh
```

### Step 7: Configure Domain (Optional)

If you have a domain name:

```bash
# Install Nginx for reverse proxy
sudo apt install nginx -y

# Create Nginx configuration
sudo nano /etc/nginx/sites-available/stock-portfolio

# Add configuration:
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:3005;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    location /api {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}

# Enable site
sudo ln -s /etc/nginx/sites-available/stock-portfolio /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

# Install SSL with Let's Encrypt
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d your-domain.com
```

---

## Independent Service Deployment

### Why Deploy Services Independently?

1. **Zero Downtime**: Update one service without affecting others
2. **Faster Deployments**: Only rebuild what changed
3. **Easier Rollbacks**: Rollback individual services
4. **Resource Efficiency**: Don't restart everything for small changes

### Deployment Workflow

#### 1. Deploy Single Service

```bash
# Deploy user service only
./deploy/deploy-service.sh user-service

# Deploy portfolio service only
./deploy/deploy-service.sh portfolio-service

# Deploy market data service only
./deploy/deploy-service.sh market-data-service

# Deploy dividend service only
./deploy/deploy-service.sh dividend-service

# Deploy frontend only
./deploy/deploy-service.sh frontend
```

#### 2. What Happens During Deployment

```
1. Stop old container
2. Remove old container
3. Build new Docker image
4. Start new container
5. Verify health
6. Report status
```

#### 3. Verify Deployment

```bash
# Check specific service logs
docker logs -f stock-portfolio-user-service

# Check all services
./deploy/health-check.sh

# Test service endpoint
curl http://localhost:3001/health
```

#### 4. Rollback if Needed

```bash
# Rollback to previous version
./deploy/rollback-service.sh user-service previous

# Rollback to specific version
./deploy/rollback-service.sh user-service v1.2.0
```

### Example: Updating User Service

```bash
# 1. Make code changes in user-service/
cd user-service/src
nano index.js
# ... make changes ...

# 2. Commit changes
git add .
git commit -m "Update user service: add email verification"
git push

# 3. On EC2, pull latest code
cd /home/ubuntu/stock-portfolio
git pull origin main

# 4. Deploy only user service
./deploy/deploy-service.sh user-service

# 5. Verify
curl http://localhost:3001/health
docker logs stock-portfolio-user-service
```

### CI/CD Pipeline (GitHub Actions)

Create `.github/workflows/deploy-service.yml`:

```yaml
name: Deploy Service

on:
  push:
    paths:
      - 'user-service/**'
      - 'portfolio-service/**'
      - 'market-data-service/**'
      - 'dividend-service/**'
      - 'frontend/**'

jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      user-service: ${{ steps.changes.outputs.user-service }}
      portfolio-service: ${{ steps.changes.outputs.portfolio-service }}
      market-data-service: ${{ steps.changes.outputs.market-data-service }}
      dividend-service: ${{ steps.changes.outputs.dividend-service }}
      frontend: ${{ steps.changes.outputs.frontend }}
    steps:
      - uses: actions/checkout@v3
      - uses: dorny/paths-filter@v2
        id: changes
        with:
          filters: |
            user-service:
              - 'user-service/**'
            portfolio-service:
              - 'portfolio-service/**'
            market-data-service:
              - 'market-data-service/**'
            dividend-service:
              - 'dividend-service/**'
            frontend:
              - 'frontend/**'

  deploy:
    needs: detect-changes
    runs-on: ubuntu-latest
    steps:
      - name: Deploy User Service
        if: needs.detect-changes.outputs.user-service == 'true'
        run: |
          ssh -i ${{ secrets.EC2_KEY }} ubuntu@${{ secrets.EC2_HOST }} \
          "cd stock-portfolio && git pull && ./deploy/deploy-service.sh user-service"

      - name: Deploy Portfolio Service
        if: needs.detect-changes.outputs.portfolio-service == 'true'
        run: |
          ssh -i ${{ secrets.EC2_KEY }} ubuntu@${{ secrets.EC2_HOST }} \
          "cd stock-portfolio && git pull && ./deploy/deploy-service.sh portfolio-service"
      
      # Add more services as needed
```

---

## Environment Configuration

### Complete .env File

Create `.env` in project root:

```bash
#==========================================
# DATABASE CONFIGURATION
#==========================================
POSTGRES_USER=stockuser
POSTGRES_PASSWORD=YOUR_SECURE_DB_PASSWORD_HERE
POSTGRES_DB=stockportfolio
POSTGRES_HOST=postgres
POSTGRES_PORT=5432

#==========================================
# REDIS CONFIGURATION
#==========================================
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=YOUR_SECURE_REDIS_PASSWORD_HERE

#==========================================
# JWT AUTHENTICATION
#==========================================
JWT_SECRET=YOUR_VERY_LONG_RANDOM_JWT_SECRET_KEY_HERE
JWT_EXPIRY=7d

#==========================================
# EXTERNAL API KEYS
#==========================================
ALPHA_VANTAGE_API_KEY=YOUR_ALPHA_VANTAGE_API_KEY_HERE

#==========================================
# SERVICE PORTS
#==========================================
USER_SERVICE_PORT=3001
PORTFOLIO_SERVICE_PORT=3002
MARKET_DATA_SERVICE_PORT=3003
DIVIDEND_SERVICE_PORT=3004
API_GATEWAY_PORT=3000
FRONTEND_PORT=3005

#==========================================
# APPLICATION CONFIGURATION
#==========================================
NODE_ENV=production
LOG_LEVEL=info
CORS_ORIGIN=*

#==========================================
# RATE LIMITING
#==========================================
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100

#==========================================
# CACHE CONFIGURATION
#==========================================
CACHE_TTL=300
MARKET_DATA_CACHE_TTL=60
```

### Generate Secure Passwords

```bash
# Generate random password
openssl rand -base64 32

# Generate JWT secret
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"

# Or use online generator
# https://randomkeygen.com/
```

### .env.example File

Create `.env.example` (commit to git):

```bash
#==========================================
# DATABASE CONFIGURATION
#==========================================
POSTGRES_USER=stockuser
POSTGRES_PASSWORD=CHANGE_ME
POSTGRES_DB=stockportfolio
POSTGRES_HOST=postgres
POSTGRES_PORT=5432

#==========================================
# REDIS CONFIGURATION
#==========================================
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=CHANGE_ME

#==========================================
# JWT AUTHENTICATION
#==========================================
JWT_SECRET=CHANGE_ME_TO_RANDOM_STRING
JWT_EXPIRY=7d

#==========================================
# EXTERNAL API KEYS
#==========================================
ALPHA_VANTAGE_API_KEY=GET_FROM_ALPHAVANTAGE_CO

#==========================================
# SERVICE PORTS
#==========================================
USER_SERVICE_PORT=3001
PORTFOLIO_SERVICE_PORT=3002
MARKET_DATA_SERVICE_PORT=3003
DIVIDEND_SERVICE_PORT=3004
API_GATEWAY_PORT=3000
FRONTEND_PORT=3005

#==========================================
# APPLICATION CONFIGURATION
#==========================================
NODE_ENV=production
LOG_LEVEL=info
CORS_ORIGIN=*
```

### Database Initialization Script

Create `init-db.sql`:

```sql
-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create portfolio table
CREATE TABLE IF NOT EXISTS portfolio (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    symbol VARCHAR(10) NOT NULL,
    shares DECIMAL(10,2) DEFAULT 0,
    purchase_price DECIMAL(10,2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, symbol)
);

-- Create budget table
CREATE TABLE IF NOT EXISTS budget (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE UNIQUE,
    total_budget DECIMAL(15,2) NOT NULL,
    allocated DECIMAL(15,2) DEFAULT 0,
    available DECIMAL(15,2) GENERATED ALWAYS AS (total_budget - allocated) STORED,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create dividend history table
CREATE TABLE IF NOT EXISTS dividend_history (
    id SERIAL PRIMARY KEY,
    symbol VARCHAR(10) NOT NULL,
    ex_date DATE NOT NULL,
    payment_date DATE,
    amount DECIMAL(10,4) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(symbol, ex_date)
);

-- Create indexes for performance
CREATE INDEX idx_portfolio_user_id ON portfolio(user_id);
CREATE INDEX idx_portfolio_symbol ON portfolio(symbol);
CREATE INDEX idx_dividend_symbol ON dividend_history(symbol);
CREATE INDEX idx_users_email ON users(email);

-- Create function to update timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for users table
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create trigger for budget table
CREATE TRIGGER update_budget_updated_at BEFORE UPDATE ON budget
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert sample data (optional, for testing)
-- INSERT INTO users (email, password_hash, name) VALUES
-- ('demo@example.com', '$2b$10$rQZ8kqV1qQZ8kqV1qQZ8kO', 'Demo User');
```

---

## API Documentation

### User Service API

#### Register User
```http
POST /api/users/register
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "SecurePassword123!",
  "name": "John Doe"
}

Response: 201 Created
{
  "message": "User registered successfully",
  "user": {
    "id": 1,
    "email": "user@example.com",
    "name": "John Doe",
    "createdAt": "2025-10-21T10:00:00Z"
  },
  "token": "eyJhbGciOiJIUzI1NiIs..."
}
```

#### Login
```http
POST /api/users/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "SecurePassword123!"
}

Response: 200 OK
{
  "message": "Login successful",
  "user": {
    "id": 1,
    "email": "user@example.com",
    "name": "John Doe"
  },
  "token": "eyJhbGciOiJIUzI1NiIs..."
}
```

#### Get Profile
```http
GET /api/users/profile
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...

Response: 200 OK
{
  "user": {
    "id": 1,
    "email": "user@example.com",
    "name": "John Doe",
    "created_at": "2025-10-21T10:00:00Z"
  }
}
```

### Portfolio Service API

#### Add Ticker
```http
POST /api/portfolio/tickers
Authorization: Bearer <token>
Content-Type: application/json

{
  "symbol": "AAPL",
  "shares": 10,
  "purchasePrice": 150.50
}

Response: 201 Created
{
  "message": "Ticker added successfully",
  "ticker": {
    "id": 1,
    "user_id": 1,
    "symbol": "AAPL",
    "shares": 10,
    "purchase_price": 150.50
  }
}
```

#### Get Tickers
```http
GET /api/portfolio/tickers
Authorization: Bearer <token>

Response: 200 OK
{
  "tickers": [
    {
      "id": 1,
      "symbol": "AAPL",
      "shares": 10,
      "purchase_price": 150.50
    }
  ]
}
```

#### Set Budget
```http
PUT /api/portfolio/budget
Authorization: Bearer <token>
Content-Type: application/json

{
  "totalBudget": 10000
}

Response: 200 OK
{
  "message": "Budget updated successfully",
  "budget": {
    "total_budget": 10000,
    "allocated": 1505,
    "available": 8495
  }
}
```

### Market Data Service API

#### Get Quote
```http
GET /api/market/quote/AAPL
Authorization: Bearer <token>

Response: 200 OK
{
  "symbol": "AAPL",
  "price": 175.50,
  "change": 2.50,
  "changePercent": 1.45,
  "volume": 50000000,
  "lastUpdated": "2025-10-21T15:30:00Z"
}
```

### Dividend Service API

#### Get Dividend Tickers
```http
GET /api/dividends/tickers
Authorization: Bearer <token>

Response: 200 OK
{
  "tickers": [
    {
      "symbol": "AAPL",
      "dividendYield": 0.52,
      "annualDividend": 0.92,
      "paymentFrequency": "quarterly"
    }
  ]
}
```

#### Get Projection
```http
GET /api/dividends/projection
Authorization: Bearer <token>

Response: 200 OK
{
  "totalAnnualDividend": 92.00,
  "projections": [
    {
      "symbol": "AAPL",
      "shares": 10,
      "annualDividend": 9.20,
      "quarterlyPayments": [
        {"quarter": "Q1", "amount": 2.30},
        {"quarter": "Q2", "amount": 2.30},
        {"quarter": "Q3", "amount": 2.30},
        {"quarter": "Q4", "amount": 2.30}
      ]
    }
  ]
}
```

---

## Monitoring & Troubleshooting

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker logs -f stock-portfolio-user-service
docker logs -f stock-portfolio-portfolio-service
docker logs -f stock-portfolio-market-data-service
docker logs -f stock-portfolio-dividend-service

# Last 100 lines
docker logs --tail 100 stock-portfolio-user-service

# Since specific time
docker logs --since 1h stock-portfolio-user-service
```

### Check Service Status

```bash
# All containers
docker ps

# Specific service
docker ps | grep user-service

# Resource usage
docker stats

# Health check
./deploy/health-check.sh
```

### Common Issues

#### Issue: Service won't start
```bash
# Check logs
docker logs stock-portfolio-user-service

# Check if port is already in use
sudo netstat -tulpn | grep 3001

# Restart service
docker-compose restart user-service
```

#### Issue: Database connection failed
```bash
# Check if PostgreSQL is running
docker ps | grep postgres

# Check database logs
docker logs stock-portfolio-postgres

# Connect to database
docker exec -it stock-portfolio-postgres psql -U stockuser -d stockportfolio

# Check connectivity from service
docker exec -it stock-portfolio-user-service ping postgres
```

#### Issue: Redis connection failed
```bash
# Check Redis
docker logs stock-portfolio-redis

# Test Redis connection
docker exec -it stock-portfolio-redis redis-cli ping

# Check password
docker exec -it stock-portfolio-redis redis-cli -a your_password ping
```

#### Issue: API calls failing
```bash
# Check API Gateway logs
docker logs stock-portfolio-api-gateway

# Test service endpoint directly
curl http://localhost:3001/health
curl http://localhost:3002/health

# Check CORS settings
curl -H "Origin: http://localhost:3005" \
     -H "Access-Control-Request-Method: POST" \
     -H "Access-Control-Request-Headers: Content-Type" \
     -X OPTIONS http://localhost:3000/api/users/login
```

### Performance Monitoring

```bash
# Monitor resource usage
docker stats --no-stream

# Check database performance
docker exec -it stock-portfolio-postgres psql -U stockuser -d stockportfolio -c "
SELECT pid, now() - query_start AS duration, query 
FROM pg_stat_activity 
WHERE state = 'active' 
ORDER BY duration DESC;"

# Check Redis cache hit rate
docker exec -it stock-portfolio-redis redis-cli --stat
```

### Backup and Restore

```bash
# Backup database
docker exec stock-portfolio-postgres pg_dump -U stockuser stockportfolio > backup_$(date +%Y%m%d_%H%M%S).sql

# Restore database
docker exec -i stock-portfolio-postgres psql -U stockuser stockportfolio < backup_20251021_120000.sql

# Backup Redis
docker exec stock-portfolio-redis redis-cli --rdb /data/dump.rdb

# Copy backup from container
docker cp stock-portfolio-redis:/data/dump.rdb ./redis_backup.rdb
```

### Automated Monitoring Script

Create `monitor.sh`:

```bash
#!/bin/bash
# monitor.sh - Continuous monitoring script

while true; do
    clear
    echo "==================================="
    echo "Stock Portfolio System Monitor"
    echo "Time: $(date)"
    echo "==================================="
    echo ""
    
    echo "Container Status:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep stock-portfolio
    echo ""
    
    echo "Resource Usage:"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep stock-portfolio
    echo ""
    
    echo "Recent Errors (last 5 minutes):"
    docker logs --since 5m stock-portfolio-user-service 2>&1 | grep -i error | tail -5
    echo ""
    
    sleep 30
done
```

---

## Security Best Practices

### 1. Secure Secrets Management

```bash
# Never commit .env to git
echo ".env" >> .gitignore

# Use Docker secrets in production
docker secret create postgres_password ./postgres_password.txt
docker secret create jwt_secret ./jwt_secret.txt

# Update docker-compose.yml to use secrets
```

### 2. Enable SSL/TLS

```bash
# Install certbot
sudo apt install certbot

# Get SSL certificate
sudo certbot certonly --standalone -d your-domain.com

# Configure Nginx for HTTPS
sudo nano /etc/nginx/sites-available/stock-portfolio
```

### 3. Implement Rate Limiting

Add to each service's `index.js`:

```javascript
const rateLimit = require('express-rate-limit');

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});

app.use('/api/', limiter);
```

### 4. Security Headers

```javascript
const helmet = require('helmet');
app.use(helmet());
```

### 5. Input Validation

```javascript
const { body, validationResult } = require('express-validator');

app.post('/api/users/register', [
  body('email').isEmail().normalizeEmail(),
  body('password').isLength({ min: 8 }),
], (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }
  // ... rest of code
});
```

---

## Scaling Strategies

### Horizontal Scaling

Add more instances of a service:

```bash
# Scale portfolio service to 3 instances
docker-compose up -d --scale portfolio-service=3

# Update Nginx to load balance
# Edit nginx/nginx.conf
upstream portfolio_backend {
    server portfolio-service-1:3002;
    server portfolio-service-2:3002;
    server portfolio-service-3:3002;
}
```

### Vertical Scaling

Increase resources for containers:

```yaml
# docker-compose.yml
services:
  user-service:
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
```

### Database Optimization

```sql
-- Add indexes
CREATE INDEX CONCURRENTLY idx_portfolio_user_symbol ON portfolio(user_id, symbol);

-- Analyze tables
ANALYZE users;
ANALYZE portfolio;

-- Vacuum database
VACUUM ANALYZE;
```

### Caching Strategy

```javascript
// Implement multi-level caching
const cache = {
  // L1: In-memory cache (fastest)
  memory: new Map(),
  
  // L2: Redis cache (shared across instances)
  async get(key) {
    // Try memory first
    if (this.memory.has(key)) return this.memory.get(key);
    
    // Try Redis
    const value = await redisClient.get(key);
    if (value) {
      this.memory.set(key, value);
      return value;
    }
    
    return null;
  },
  
  async set(key, value, ttl) {
    this.memory.set(key, value);
    await redisClient.setEx(key, ttl, value);
  }
};
```

---

## Maintenance Tasks

### Regular Maintenance Checklist

**Daily:**
- [ ] Check service health
- [ ] Review error logs
- [ ] Monitor disk space
- [ ] Check API response times

**Weekly:**
- [ ] Backup database
- [ ] Update dependencies (security patches)
- [ ] Review resource usage
- [ ] Check cache hit rates

**Monthly:**
- [ ] Full system backup
- [ ] Database optimization (VACUUM, ANALYZE)
- [ ] Review and rotate logs
- [ ] Security audit

### Maintenance Scripts

Create `maintenance.sh`:

```bash
#!/bin/bash
# maintenance.sh - Automated maintenance tasks

echo "Starting maintenance tasks..."

# 1. Backup database
echo "Backing up database..."
docker exec stock-portfolio-postgres pg_dump -U stockuser stockportfolio > \
  backups/db_backup_$(date +%Y%m%d).sql

# 2. Backup Redis
echo "Backing up Redis..."
docker exec stock-portfolio-redis redis-cli BGSAVE

# 3. Clean old logs
echo "Cleaning old logs..."
docker system prune -f --filter "until=168h"

# 4. Database optimization
echo "Optimizing database..."
docker exec stock-portfolio-postgres psql -U stockuser -d stockportfolio -c "VACUUM ANALYZE;"

# 5. Update system packages (if needed)
echo "Checking for updates..."
sudo apt update
sudo apt list --upgradable

# 6. Check disk space
echo "Disk usage:"
df -h

# 7. Generate report
echo "Generating health report..."
./deploy/health-check.sh > maintenance_report_$(date +%Y%m%d).txt

echo "Maintenance completed!"
```

### Automated Maintenance with Cron

```bash
# Edit crontab
crontab -e

# Add maintenance tasks
# Backup daily at 2 AM
0 2 * * * /home/ubuntu/stock-portfolio/maintenance.sh

# Health check every hour
0 * * * * /home/ubuntu/stock-portfolio/deploy/health-check.sh >> /var/log/stock-portfolio-health.log

# Clean old backups weekly
0 3 * * 0 find /home/ubuntu/stock-portfolio/backups -name "*.sql" -mtime +30 -delete
```

---

## Development Workflow

### Local Development Setup

```bash
# 1. Create feature branch
git checkout -b feature/new-feature

# 2. Start development environment
docker-compose -f docker-compose.dev.yml up

# 3. Make changes with hot reload enabled
# Edit files in user-service/src/

# 4. Run tests
docker exec stock-portfolio-user-service npm test

# 5. Commit and push
git add .
git commit -m "Add new feature"
git push origin feature/new-feature

# 6. Create pull request
```

### Testing

Create `docker-compose.test.yml`:

```yaml
version: '3.8'

services:
  test-postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: testuser
      POSTGRES_PASSWORD: testpass
      POSTGRES_DB: testdb
    tmpfs:
      - /var/lib/postgresql/data

  user-service-test:
    build: ./user-service
    environment:
      DATABASE_URL: postgresql://testuser:testpass@test-postgres:5432/testdb
      NODE_ENV: test
    depends_on:
      - test-postgres
    command: npm test
```

Run tests:

```bash
docker-compose -f docker-compose.test.yml up --abort-on-container-exit
```

### Code Quality

Install linting and formatting:

```bash
# In each service directory
npm install --save-dev eslint prettier

# Create .eslintrc.json
{
  "extends": ["eslint:recommended"],
  "env": {
    "node": true,
    "es6": true
  },
  "rules": {
    "no-console": "off",
    "no-unused-vars": ["error", { "argsIgnorePattern": "^_" }]
  }
}

# Create .prettierrc
{
  "semi": true,
  "trailingComma": "es5",
  "singleQuote": true,
  "printWidth": 80
}

# Add to package.json scripts
"scripts": {
  "lint": "eslint src/",
  "format": "prettier --write src/",
  "test": "jest"
}
```

---

## Troubleshooting Guide

### Problem: Port Already in Use

```bash
# Find process using port
sudo lsof -i :3001

# Kill process
sudo kill -9 <PID>

# Or change port in .env
USER_SERVICE_PORT=3011
```

### Problem: Out of Disk Space

```bash
# Check disk usage
df -h

# Clean Docker
docker system prune -a --volumes

# Remove old images
docker image prune -a

# Remove old containers
docker container prune
```

### Problem: Database Connection Pool Exhausted

```javascript
// Increase pool size in service
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 20, // increase from default 10
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});
```

### Problem: Memory Leak

```bash
# Monitor memory usage
docker stats

# Check for memory leaks in Node.js
docker exec stock-portfolio-user-service node --inspect=0.0.0.0:9229 src/index.js

# Use Chrome DevTools to profile memory
# Open chrome://inspect in Chrome
```

### Problem: Slow API Responses

```bash
# Enable query logging in PostgreSQL
docker exec stock-portfolio-postgres psql -U stockuser -d stockportfolio -c \
  "ALTER DATABASE stockportfolio SET log_min_duration_statement = 1000;"

# Check slow queries
docker exec stock-portfolio-postgres psql -U stockuser -d stockportfolio -c \
  "SELECT query, mean_exec_time FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 10;"

# Add indexes
CREATE INDEX CONCURRENTLY idx_portfolio_user_id ON portfolio(user_id);
```

---

## Quick Reference Commands

### Docker Commands

```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# Restart service
docker-compose restart user-service

# View logs
docker-compose logs -f

# Execute command in container
docker exec -it stock-portfolio-user-service bash

# Remove all containers and volumes
docker-compose down -v
```

### Service Management

```bash
# Deploy service
./deploy/deploy-service.sh user-service

# Check health
./deploy/health-check.sh

# View logs
docker logs -f stock-portfolio-user-service

# Restart service
docker-compose restart user-service
```

### Database Commands

```bash
# Connect to database
docker exec -it stock-portfolio-postgres psql -U stockuser -d stockportfolio

# List tables
\dt

# Describe table
\d users

# Run query
SELECT * FROM users LIMIT 10;

# Exit
\q
```

### Redis Commands

```bash
# Connect to Redis
docker exec -it stock-portfolio-redis redis-cli -a your_password

# Check keys
KEYS *

# Get value
GET portfolio:1

# Delete key
DEL portfolio:1

# Flush all
FLUSHALL
```

---

## Support and Resources

### Documentation Links

- Docker: https://docs.docker.com/
- Docker Compose: https://docs.docker.com/compose/
- PostgreSQL: https://www.postgresql.org/docs/
- Redis: https://redis.io/documentation
- Express.js: https://expressjs.com/
- React: https://react.dev/
- Alpha Vantage API: https://www.alphavantage.co/documentation/

### Getting Help

1. Check logs: `docker logs stock-portfolio-<service-name>`
2. Review this README
3. Check GitHub Issues
4. Contact: support@your-domain.com

### Contributing

1. Fork the repository
2. Create feature branch
3. Make changes
4. Write tests
5. Submit pull request

---

## License

MIT License - See LICENSE file for details

---

## Changelog

### Version 1.0.0 (2025-10-21)
- Initial release
- User authentication system
- Portfolio management
- Market data integration
- Dividend tracking and projections
- Microservices architecture
- Docker deployment support