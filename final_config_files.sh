# ============================================
# .env.example - Copy this to .env and fill in your values
# ============================================

#==========================================
# DATABASE CONFIGURATION
#==========================================
POSTGRES_USER=stockuser
POSTGRES_PASSWORD=CHANGE_ME_TO_SECURE_PASSWORD
POSTGRES_DB=stockportfolio
POSTGRES_HOST=postgres
POSTGRES_PORT=5432

#==========================================
# REDIS CONFIGURATION
#==========================================
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=CHANGE_ME_TO_SECURE_PASSWORD

#==========================================
# JWT AUTHENTICATION
#==========================================
JWT_SECRET=CHANGE_ME_TO_LONG_RANDOM_STRING_AT_LEAST_64_CHARS
JWT_EXPIRY=7d

#==========================================
# EXTERNAL API KEYS
#==========================================
# Get your free API key from: https://www.alphavantage.co/support/#api-key
ALPHA_VANTAGE_API_KEY=YOUR_API_KEY_HERE

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

# ============================================
# .gitignore
# ============================================

# Dependencies
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Environment
.env
.env.local
.env.production

# Build outputs
build/
dist/
*.log

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Docker
*.pid
*.seed
*.pid.lock

# Backups
backups/*.sql
backups/*.rdb
*.backup

# Certificates
*.pem
*.key
*.crt

# Logs
logs/
*.log

# ============================================
# init-db.sql - Database initialization
# ============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Create portfolio table
CREATE TABLE IF NOT EXISTS portfolio (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    symbol VARCHAR(10) NOT NULL,
    shares DECIMAL(10,2) DEFAULT 0,
    purchase_price DECIMAL(10,2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
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
CREATE INDEX IF NOT EXISTS idx_portfolio_user_id ON portfolio(user_id);
CREATE INDEX IF NOT EXISTS idx_portfolio_symbol ON portfolio(symbol);
CREATE INDEX IF NOT EXISTS idx_portfolio_user_symbol ON portfolio(user_id, symbol);
CREATE INDEX IF NOT EXISTS idx_dividend_symbol ON dividend_history(symbol);
CREATE INDEX IF NOT EXISTS idx_dividend_ex_date ON dividend_history(ex_date);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_active ON users(is_active);

-- Create function to update timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$ language 'plpgsql';

-- Create triggers for users table
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Create trigger for portfolio table
DROP TRIGGER IF EXISTS update_portfolio_updated_at ON portfolio;
CREATE TRIGGER update_portfolio_updated_at 
    BEFORE UPDATE ON portfolio
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Create trigger for budget table
DROP TRIGGER IF EXISTS update_budget_updated_at ON budget;
CREATE TRIGGER update_budget_updated_at 
    BEFORE UPDATE ON budget
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Insert sample data for testing (comment out in production)
-- INSERT INTO users (email, password_hash, name) VALUES
-- ('demo@example.com', '$2b$10$rQZ8kqV1qQZ8kqV1qQZ8kOEp3xYzK4rQZ8kqV1qQZ8kqV1qQZ8kq', 'Demo User');

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO stockuser;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO stockuser;

-- ============================================
# Complete Project Structure Generator
# generate-structure.sh
# ============================================

#!/bin/bash
# Generate complete project structure

set -e

echo "Generating Stock Portfolio project structure..."

# Create main directories
mkdir -p {user-service,portfolio-service,market-data-service,dividend-service,frontend,nginx,deploy}/src
mkdir -p backups logs

# User Service
cat > user-service/package.json << 'EOF'
{
  "name": "user-service",
  "version": "1.0.0",
  "description": "User authentication and management service",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "bcrypt": "^5.1.1",
    "jsonwebtoken": "^9.0.2",
    "pg": "^8.11.3",
    "redis": "^4.6.10",
    "cors": "^2.8.5"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
EOF

cat > user-service/Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE 3001

CMD ["node", "src/index.js"]
EOF

# Portfolio Service
cat > portfolio-service/package.json << 'EOF'
{
  "name": "portfolio-service",
  "version": "1.0.0",
  "description": "Portfolio management service",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "jsonwebtoken": "^9.0.2",
    "pg": "^8.11.3",
    "redis": "^4.6.10",
    "cors": "^2.8.5"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
EOF

cat > portfolio-service/Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE 3002

CMD ["node", "src/index.js"]
EOF

# Market Data Service
cat > market-data-service/package.json << 'EOF'
{
  "name": "market-data-service",
  "version": "1.0.0",
  "description": "Market data fetching service",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "axios": "^1.6.0",
    "redis": "^4.6.10",
    "cors": "^2.8.5"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
EOF

cat > market-data-service/Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE 3003

CMD ["node", "src/index.js"]
EOF

# Dividend Service
cat > dividend-service/package.json << 'EOF'
{
  "name": "dividend-service",
  "version": "1.0.0",
  "description": "Dividend tracking and projection service",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "axios": "^1.6.0",
    "jsonwebtoken": "^9.0.2",
    "pg": "^8.11.3",
    "redis": "^4.6.10",
    "cors": "^2.8.5"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
EOF

cat > dividend-service/Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE 3004

CMD ["node", "src/index.js"]
EOF

# Frontend
cat > frontend/package.json << 'EOF'
{
  "name": "stock-portfolio-frontend",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-scripts": "5.0.1",
    "axios": "^1.6.0"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "eslintConfig": {
    "extends": ["react-app"]
  },
  "browserslist": {
    "production": [">0.2%", "not dead", "not op_mini all"],
    "development": ["last 1 chrome version", "last 1 firefox version", "last 1 safari version"]
  }
}
EOF

cat > frontend/Dockerfile << 'EOF'
FROM node:18-alpine as build

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF

cat > frontend/nginx.conf << 'EOF'
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api {
        proxy_pass http://api-gateway;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

# Nginx API Gateway
cat > nginx/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream user_service {
        server user-service:3001;
    }

    upstream portfolio_service {
        server portfolio-service:3002;
    }

    upstream market_data_service {
        server market-data-service:3003;
    }

    upstream dividend_service {
        server dividend-service:3004;
    }

    server {
        listen 80;
        
        access_log /var/log/nginx/access.log;
        error_log /var/log/nginx/error.log;

        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'Authorization, Content-Type' always;

        if ($request_method = 'OPTIONS') {
            return 204;
        }

        location /api/users {
            proxy_pass http://user_service;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        location /api/portfolio {
            proxy_pass http://portfolio_service;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        location /api/market {
            proxy_pass http://market_data_service;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        location /api/dividends {
            proxy_pass http://dividend_service;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        location /health {
            return 200 '{"status":"healthy","service":"api-gateway"}';
            add_header Content-Type application/json;
        }
    }
}
EOF

cat > nginx/Dockerfile << 'EOF'
FROM nginx:alpine
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF

# Create README
cat > README.md << 'EOF'
# Stock Portfolio Management System

A microservices-based stock portfolio management system built with Docker.

## Quick Start

1. Copy `.env.example` to `.env` and fill in your values
2. Run `./deploy/base-setup.sh` to setup infrastructure
3. Run `docker-compose up -d` to start all services

## Documentation

See the complete documentation in the artifacts for:
- Full deployment guide
- API documentation
- Troubleshooting
- Security best practices

## Services

- User Service (3001): Authentication
- Portfolio Service (3002): Portfolio management
- Market Data Service (3003): Stock prices
- Dividend Service (3004): Dividend tracking
- Frontend (3005): Web interface
- API Gateway (3000): Request routing

## Support

For issues, see the troubleshooting section in the documentation.
EOF

echo "✅ Project structure generated successfully!"
echo ""
echo "Next steps:"
echo "1. Copy service implementation code to respective src/ directories"
echo "2. Copy .env.example to .env and configure"
echo "3. Run: chmod +x deploy/*.sh"
echo "4. Run: ./deploy/base-setup.sh"

# ============================================
# Quick Start Guide - QUICKSTART.md
# ============================================

## QUICK START GUIDE

### Prerequisites
- Docker & Docker Compose installed
- Alpha Vantage API key (get free at https://www.alphavantage.co/support/#api-key)

### Step 1: Clone and Setup
```bash
git clone <your-repo>
cd stock-portfolio
cp .env.example .env
```

### Step 2: Configure Environment
Edit `.env` file and set:
```bash
POSTGRES_PASSWORD=your_secure_password
REDIS_PASSWORD=your_redis_password
JWT_SECRET=your_long_random_secret
ALPHA_VANTAGE_API_KEY=your_api_key
```

Generate secure values:
```bash
# Generate passwords
openssl rand -base64 32

# Generate JWT secret
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
```

### Step 3: Deploy
```bash
# Make scripts executable
chmod +x deploy/*.sh

# Setup base infrastructure
./deploy/base-setup.sh

# Start all services
docker-compose up -d

# Check status
./deploy/health-check.sh
```

### Step 4: Access Application
- Frontend: http://localhost:3005
- API Gateway: http://localhost:3000

### Step 5: Test
1. Register a new account
2. Add a ticker (e.g., AAPL, MSFT)
3. Set your budget
4. View dividend projections

### Common Commands
```bash
# View logs
docker-compose logs -f

# Restart service
docker-compose restart user-service

# Stop all
docker-compose down

# Deploy single service
./deploy/deploy-service.sh user-service

# Health check
./deploy/health-check.sh
```

### Troubleshooting
```bash
# Service won't start
docker logs stock-portfolio-user-service

# Database issues
docker exec -it stock-portfolio-postgres psql -U stockuser -d stockportfolio

# Redis issues
docker exec -it stock-portfolio-redis redis-cli -a your_password ping

# Clean restart
docker-compose down -v
./deploy/base-setup.sh
docker-compose up -d
```

### EC2 Deployment
```bash
# On EC2 instance
curl -o ec2-setup.sh https://raw.githubusercontent.com/<your-repo>/main/deploy/ec2-setup.sh
chmod +x ec2-setup.sh
./ec2-setup.sh

# Then follow local deployment steps
```

For detailed documentation, see the complete README and deployment guides.

# ============================================
# Docker Compose Override for Development
# docker-compose.dev.yml
# ============================================

version: '3.8'

services:
  user-service:
    build:
      context: ./user-service
      dockerfile: Dockerfile
    volumes:
      - ./user-service/src:/app/src
    environment:
      NODE_ENV: development
    command: npm run dev

  portfolio-service:
    build:
      context: ./portfolio-service
      dockerfile: Dockerfile
    volumes:
      - ./portfolio-service/src:/app/src
    environment:
      NODE_ENV: development
    command: npm run dev

  market-data-service:
    build:
      context: ./market-data-service
      dockerfile: Dockerfile
    volumes:
      - ./market-data-service/src:/app/src
    environment:
      NODE_ENV: development
    command: npm run dev

  dividend-service:
    build:
      context: ./dividend-service
      dockerfile: Dockerfile
    volumes:
      - ./dividend-service/src:/app/src
    environment:
      NODE_ENV: development
    command: npm run dev

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile.dev
    volumes:
      - ./frontend/src:/app/src
      - ./frontend/public:/app/public
    environment:
      NODE_ENV: development
    command: npm start

# Usage: docker-compose -f docker-compose.yml -f docker-compose.dev.yml up

# ============================================
# Makefile for Common Tasks
# ============================================

.PHONY: help setup start stop restart logs clean deploy-service health

help:
	@echo "Available commands:"
	@echo "  make setup          - Initial setup"
	@echo "  make start          - Start all services"
	@echo "  make stop           - Stop all services"
	@echo "  make restart        - Restart all services"
	@echo "  make logs           - View logs"
	@echo "  make health         - Check service health"
	@echo "  make clean          - Clean up containers and volumes"
	@echo "  make deploy-user    - Deploy user service"
	@echo "  make deploy-portfolio - Deploy portfolio service"
	@echo "  make backup         - Backup database"

setup:
	@echo "Setting up project..."
	@cp .env.example .env || true
	@chmod +x deploy/*.sh
	@./deploy/base-setup.sh

start:
	@docker-compose up -d

stop:
	@docker-compose down

restart:
	@docker-compose restart

logs:
	@docker-compose logs -f

health:
	@./deploy/health-check.sh

clean:
	@docker-compose down -v
	@docker system prune -f

deploy-user:
	@./deploy/deploy-service.sh user-service

deploy-portfolio:
	@./deploy/deploy-service.sh portfolio-service

deploy-market:
	@./deploy/deploy-service.sh market-data-service

deploy-dividend:
	@./deploy/deploy-service.sh dividend-service

deploy-frontend:
	@./deploy/deploy-service.sh frontend

backup:
	@./backup.sh

# ============================================
# CI/CD GitHub Actions Workflow
# .github/workflows/deploy.yml
# ============================================

name: Deploy Services

on:
  push:
    branches: [ main ]
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
      user: ${{ steps.filter.outputs.user }}
      portfolio: ${{ steps.filter.outputs.portfolio }}
      market: ${{ steps.filter.outputs.market }}
      dividend: ${{ steps.filter.outputs.dividend }}
      frontend: ${{ steps.filter.outputs.frontend }}
    steps:
      - uses: actions/checkout@v3
      - uses: dorny/paths-filter@v2
        id: filter
        with:
          filters: |
            user:
              - 'user-service/**'
            portfolio:
              - 'portfolio-service/**'
            market:
              - 'market-data-service/**'
            dividend:
              - 'dividend-service/**'
            frontend:
              - 'frontend/**'

  deploy:
    needs: detect-changes
    runs-on: ubuntu-latest
    if: |
      needs.detect-changes.outputs.user == 'true' ||
      needs.detect-changes.outputs.portfolio == 'true' ||
      needs.detect-changes.outputs.market == 'true' ||
      needs.detect-changes.outputs.dividend == 'true' ||
      needs.detect-changes.outputs.frontend == 'true'
    steps:
      - name: Deploy User Service
        if: needs.detect-changes.outputs.user == 'true'
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.EC2_HOST }}
          username: ubuntu
          key: ${{ secrets.EC2_SSH_KEY }}
          script: |
            cd ~/stock-portfolio
            git pull origin main
            ./deploy/deploy-service.sh user-service

      - name: Deploy Portfolio Service
        if: needs.detect-changes.outputs.portfolio == 'true'
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.EC2_HOST }}
          username: ubuntu
          key: ${{ secrets.EC2_SSH_KEY }}
          script: |
            cd ~/stock-portfolio
            git pull origin main
            ./deploy/deploy-service.sh portfolio-service

      - name: Deploy Market Data Service
        if: needs.detect-changes.outputs.market == 'true'
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.EC2_HOST }}
          username: ubuntu
          key: ${{ secrets.EC2_SSH_KEY }}
          script: |
            cd ~/stock-portfolio
            git pull origin main
            ./deploy/deploy-service.sh market-data-service

      - name: Deploy Dividend Service
        if: needs.detect-changes.outputs.dividend == 'true'
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.EC2_HOST }}
          username: ubuntu
          key: ${{ secrets.EC2_SSH_KEY }}
          script: |
            cd ~/stock-portfolio
            git pull origin main
            ./deploy/deploy-service.sh dividend-service

      - name: Deploy Frontend
        if: needs.detect-changes.outputs.frontend == 'true'
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.EC2_HOST }}
          username: ubuntu
          key: ${{ secrets.EC2_SSH_KEY }}
          script: |
            cd ~/stock-portfolio
            git pull origin main
            ./deploy/deploy-service.sh frontend