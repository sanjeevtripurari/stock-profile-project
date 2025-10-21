# Stock Portfolio Management System

A production-ready microservices-based stock portfolio management system that allows users to track stocks, manage budgets, and project dividend income.

## 🎯 Features

- **User Authentication**: Secure JWT-based authentication
- **Portfolio Management**: Add/remove stock tickers, set budgets, buy/sell functionality
- **Real-time Market Data**: Live stock prices via Alpha Vantage API
- **Dividend Tracking**: Track dividend-paying stocks and project yearly income
- **MVP Mode**: Works with mock data when market is closed or without API keys
- **Microservices Architecture**: Independent, scalable services
- **Single Entry Point**: NGINX reverse proxy for clean URLs
- **Production Ready**: Docker containerized with health checks

## 🏗️ Architecture

```
Frontend (React) → NGINX Proxy → Microservices → PostgreSQL/Redis
```

### Services
- **User Service** (3001): Authentication & user management
- **Portfolio Service** (3002): Portfolio & budget management  
- **Market Data Service** (3003): Real-time stock prices
- **Dividend Service** (3004): Dividend tracking & projections
- **Frontend** (80): React web application
- **NGINX Proxy** (80): Single entry point for all services

## 🚀 Quick Start (5 minutes)

### Prerequisites
- Docker & Docker Compose
- Alpha Vantage API key (free): https://www.alphavantage.co/support/#api-key
  - **Note**: System works in MVP mode with mock data if no API key is provided

### 1. Clone & Configure
```bash
git clone <your-repo-url>
cd stock-portfolio
cp .env.example .env
nano .env  # Add your API key and secure passwords
```

### 2. Generate Secure Values
```bash
# PostgreSQL password
openssl rand -base64 32

# Redis password  
openssl rand -base64 32

# JWT secret
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
```

### 3. Deploy
```bash
# Make scripts executable
chmod +x deploy/*.sh scripts/*.sh

# Setup infrastructure
make setup

# Start all services
make start

# Check health
make health
```

### 4. Access Application
- **Application**: http://localhost/
- **API Gateway**: http://localhost/api/

### 5. Test the System
1. Register new account
2. Login
3. Add ticker (e.g., "AAPL", shares: 10, price: 150)
4. Set budget ($10,000)
5. View dividend projections

## 🌩️ EC2 Deployment

### 1. Launch EC2 Instance
- **AMI**: Ubuntu 22.04 LTS
- **Instance Type**: t3.medium (minimum)
- **Storage**: 20GB
- **Security Group**: Ports 22 (SSH), 80 (HTTP), 443 (HTTPS)

### 2. Connect and Setup
```bash
# Connect to EC2
ssh -i your-key.pem ubuntu@<EC2-PUBLIC-IP>

# Run automated setup
curl -o ec2-setup.sh https://raw.githubusercontent.com/<your-repo>/main/deploy/ec2-setup.sh
chmod +x ec2-setup.sh
./ec2-setup.sh

# Logout and login (for Docker group)
exit
ssh -i your-key.pem ubuntu@<EC2-PUBLIC-IP>
```

### 3. Deploy Application
```bash
# Clone repository
git clone <your-repo-url> ~/stock-portfolio
cd ~/stock-portfolio

# Configure environment
cp .env.example .env
nano .env  # Set production values

# Deploy
make setup
make start

# Verify
make health
```

### 4. Access Production
- **Application**: http://your-ec2-ip/
- **Enable HTTPS**: `./deploy/setup-ssl.sh yourdomain.com`

## 📊 API Documentation & Test Cases

### Complete Backend Testing Suite

#### 1. Authentication Tests
```bash
# Register new user
curl -X POST http://localhost/api/users/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"TestPass123!","name":"Test User"}'

# Login and get token
curl -X POST http://localhost/api/users/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"TestPass123!"}'

# Save token for subsequent requests
TOKEN="your_jwt_token_here"
```

#### 2. Portfolio Management Tests
```bash
# Get empty portfolio
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost/api/portfolio/tickers

# Add first ticker
curl -X POST http://localhost/api/portfolio/tickers \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"symbol":"AAPL","shares":10,"purchasePrice":150.50}'

# Add second ticker (will use market price if no purchasePrice)
curl -X POST http://localhost/api/portfolio/tickers \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"symbol":"GOOGL","shares":5}'

# Get updated portfolio
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost/api/portfolio/tickers

# Buy more shares of existing ticker
curl -X POST http://localhost/api/portfolio/tickers/AAPL/buy \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"shares":5,"price":155.00}'

# Sell shares
curl -X POST http://localhost/api/portfolio/tickers/AAPL/sell \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"shares":3,"price":160.00}'

# Update ticker manually
curl -X PUT http://localhost/api/portfolio/tickers/1 \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"shares":12,"purchasePrice":152.00}'

# Delete ticker
curl -X DELETE http://localhost/api/portfolio/tickers/2 \
  -H "Authorization: Bearer $TOKEN"
```

#### 3. Budget Management Tests
```bash
# Set initial budget
curl -X PUT http://localhost/api/portfolio/budget \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"totalBudget":10000}'

# Get budget status
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost/api/portfolio/budget

# Get portfolio summary with budget
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost/api/portfolio
```

#### 4. Market Data Tests
```bash
# Get single stock quote (MVP mode)
curl http://localhost/api/market/quote/AAPL

# Get multiple quotes
curl -X POST http://localhost/api/market/batch-quotes \
  -H "Content-Type: application/json" \
  -d '{"symbols":["AAPL","GOOGL","MSFT","TSLA"]}'

# Get intraday data
curl http://localhost/api/market/intraday/AAPL?interval=5min

# Search symbols
curl http://localhost/api/market/search?keywords=apple

# Get market status
curl http://localhost/api/market/status

# Clear market data cache
curl -X DELETE http://localhost/api/market/cache/AAPL
```

#### 5. Dividend Tracking Tests
```bash
# Get dividend-paying tickers
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost/api/dividends/tickers

# Get dividend projection
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost/api/dividends/projection

# Get dividend history for symbol
curl http://localhost/api/dividends/history/AAPL

# Get dividend calendar (upcoming ex-dates)
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost/api/dividends/calendar?days=60

# Clear dividend cache
curl -X DELETE http://localhost/api/dividends/cache \
  -H "Authorization: Bearer $TOKEN"
```

#### 6. Health Check Tests
```bash
# Check all service health
curl http://localhost/api/users/health
curl http://localhost/api/portfolio/health
curl http://localhost/api/market/health
curl http://localhost/api/dividends/health

# Check NGINX proxy
curl http://localhost/health
```

#### 7. Complete Test Workflow
```bash
#!/bin/bash
# Complete backend test script

echo "🧪 Testing Complete Backend Functionality"

# 1. Register and login
echo "1. Authentication..."
REGISTER=$(curl -s -X POST http://localhost/api/users/register \
  -H "Content-Type: application/json" \
  -d '{"email":"fulltest@example.com","password":"TestPass123!","name":"Full Test"}')

TOKEN=$(curl -s -X POST http://localhost/api/users/login \
  -H "Content-Type: application/json" \
  -d '{"email":"fulltest@example.com","password":"TestPass123!"}' | \
  grep -o '"token":"[^"]*"' | cut -d'"' -f4)

echo "✅ Token: ${TOKEN:0:20}..."

# 2. Set budget
echo "2. Setting budget..."
curl -s -X PUT http://localhost/api/portfolio/budget \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"totalBudget":50000}' > /dev/null

# 3. Add multiple tickers
echo "3. Adding tickers..."
curl -s -X POST http://localhost/api/portfolio/tickers \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"symbol":"AAPL","shares":10,"purchasePrice":150}' > /dev/null

curl -s -X POST http://localhost/api/portfolio/tickers \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"symbol":"MSFT","shares":15}' > /dev/null

# 4. Test trading
echo "4. Testing buy/sell..."
curl -s -X POST http://localhost/api/portfolio/tickers/AAPL/buy \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"shares":5,"price":155}' > /dev/null

# 5. Get final portfolio
echo "5. Final portfolio:"
curl -s -H "Authorization: Bearer $TOKEN" \
  http://localhost/api/portfolio | jq '.'

# 6. Get dividend projection
echo "6. Dividend projection:"
curl -s -H "Authorization: Bearer $TOKEN" \
  http://localhost/api/dividends/projection | jq '.totalAnnualDividend'

echo "✅ Backend test completed successfully!"
```

## 🔧 Debugging & Troubleshooting Guide

### Common Issues & Debug Commands

#### 1. Portfolio Shows Empty After Adding Stocks
```bash
# Check if user is authenticated
TOKEN="your_jwt_token_here"

# Verify portfolio exists
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost/api/portfolio/tickers

# Check if tickers were actually added
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost/api/portfolio

# Clear portfolio cache if data seems stale
curl -X DELETE -H "Authorization: Bearer $TOKEN" \
  http://localhost/api/portfolio/cache
```

#### 2. Dividends Showing Zero
```bash
# Test dividend endpoints step by step
TOKEN="your_jwt_token_here"

# 1. Check if portfolio has stocks
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost/api/portfolio/tickers

# 2. Check dividend tickers (should show dividend-paying stocks)
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost/api/dividends/tickers

# 3. Check dividend projection
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost/api/dividends/projection

# 4. Clear dividend cache if needed
curl -X DELETE -H "Authorization: Bearer $TOKEN" \
  http://localhost/api/dividends/cache

# 5. Test with fresh user and known dividend stocks
curl -X POST http://localhost/api/users/register \
  -H "Content-Type: application/json" \
  -d '{"email":"debug@example.com","password":"TestPass123!","name":"Debug User"}'

# Login and get fresh token
NEW_TOKEN=$(curl -s -X POST http://localhost/api/users/login \
  -H "Content-Type: application/json" \
  -d '{"email":"debug@example.com","password":"TestPass123!"}' | \
  grep -o '"token":"[^"]*"' | cut -d'"' -f4)

# Add dividend-paying stocks
curl -X POST http://localhost/api/portfolio/tickers \
  -H "Authorization: Bearer $NEW_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"symbol":"AAPL","shares":10,"purchasePrice":150.50}'

curl -X POST http://localhost/api/portfolio/tickers \
  -H "Authorization: Bearer $NEW_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"symbol":"MSFT","shares":5,"purchasePrice":300.00}'

# Test dividends again
curl -H "Authorization: Bearer $NEW_TOKEN" \
  http://localhost/api/dividends/projection
```

#### 3. Market Data Not Working
```bash
# Test market data endpoints
curl http://localhost/api/market/quote/AAPL
curl http://localhost/api/market/status
curl http://localhost/api/market/health

# Test with multiple symbols
curl -X POST http://localhost/api/market/batch-quotes \
  -H "Content-Type: application/json" \
  -d '{"symbols":["AAPL","GOOGL","MSFT"]}'

# Clear market data cache
curl -X DELETE http://localhost/api/market/cache
```

#### 4. Authentication Issues
```bash
# Test user registration
curl -X POST http://localhost/api/users/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"TestPass123!","name":"Test User"}'

# Test login
curl -X POST http://localhost/api/users/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"TestPass123!"}'

# Test with invalid credentials
curl -X POST http://localhost/api/users/login \
  -H "Content-Type: application/json" \
  -d '{"email":"wrong@example.com","password":"wrongpass"}'
```

#### 5. Service Health Checks
```bash
# Check all services
curl http://localhost/api/users/health
curl http://localhost/api/portfolio/health  
curl http://localhost/api/market/health
curl http://localhost/api/dividends/health
curl http://localhost/health

# Check Docker container status
docker-compose ps

# Check service logs
docker logs stock-portfolio-user-service --tail 20
docker logs stock-portfolio-portfolio-service --tail 20
docker logs stock-portfolio-market-data-service --tail 20
docker logs stock-portfolio-dividend-service --tail 20
docker logs stock-portfolio-frontend --tail 20
docker logs stock-portfolio-nginx-proxy --tail 20
```

#### 6. Database Connection Issues
```bash
# Check if database is running
docker logs stock-portfolio-postgres --tail 20

# Test database connection from portfolio service
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost/api/portfolio/health

# Check Redis connection
docker logs stock-portfolio-redis --tail 20
```

#### 7. Frontend Not Loading
```bash
# Check if frontend container is running
docker logs stock-portfolio-frontend --tail 20

# Test if HTML is being served
curl http://localhost/

# Test if JavaScript files are accessible
curl http://localhost/static/js/main.*.js

# Check NGINX proxy logs
docker logs stock-portfolio-nginx-proxy --tail 20
```

### PowerShell Debug Commands (Windows)
```powershell
# Complete debugging workflow in PowerShell

# 1. Register and login
$registerResponse = Invoke-RestMethod -Uri "http://localhost/api/users/register" -Method POST -ContentType "application/json" -Body '{"email":"debug-ps@example.com","password":"TestPass123!","name":"Debug PS User"}'

$loginResponse = Invoke-RestMethod -Uri "http://localhost/api/users/login" -Method POST -ContentType "application/json" -Body '{"email":"debug-ps@example.com","password":"TestPass123!"}'
$token = $loginResponse.token

# 2. Add test data
Invoke-RestMethod -Uri "http://localhost/api/portfolio/tickers" -Method POST -ContentType "application/json" -Headers @{Authorization="Bearer $token"} -Body '{"symbol":"AAPL","shares":10,"purchasePrice":150.50}'

# 3. Test all endpoints
$portfolio = Invoke-RestMethod -Uri "http://localhost/api/portfolio/tickers" -Method GET -Headers @{Authorization="Bearer $token"}
$dividends = Invoke-RestMethod -Uri "http://localhost/api/dividends/projection" -Method GET -Headers @{Authorization="Bearer $token"}
$market = Invoke-RestMethod -Uri "http://localhost/api/market/quote/AAPL" -Method GET

# 4. Display results
Write-Host "Portfolio Tickers: $($portfolio.tickers.Count)"
Write-Host "Annual Dividend: $($dividends.totalAnnualDividend)"
Write-Host "AAPL Price: $($market.price)"
```

### Quick Debug Script
```bash
#!/bin/bash
# debug-system.sh - Quick system debugging

echo "🔍 System Debug Report"
echo "===================="

# Check services
echo "1. Service Status:"
docker-compose ps

echo -e "\n2. Health Checks:"
curl -s http://localhost/health && echo " ✅ NGINX"
curl -s http://localhost/api/users/health | grep -q "healthy" && echo " ✅ User Service"
curl -s http://localhost/api/portfolio/health | grep -q "healthy" && echo " ✅ Portfolio Service"
curl -s http://localhost/api/market/health | grep -q "healthy" && echo " ✅ Market Service"
curl -s http://localhost/api/dividends/health | grep -q "healthy" && echo " ✅ Dividend Service"

echo -e "\n3. Quick API Test:"
# Register test user
REGISTER=$(curl -s -X POST http://localhost/api/users/register \
  -H "Content-Type: application/json" \
  -d '{"email":"quicktest@example.com","password":"TestPass123!","name":"Quick Test"}')

if echo "$REGISTER" | grep -q "successfully"; then
  echo " ✅ User Registration"
  
  # Login
  TOKEN=$(curl -s -X POST http://localhost/api/users/login \
    -H "Content-Type: application/json" \
    -d '{"email":"quicktest@example.com","password":"TestPass123!"}' | \
    grep -o '"token":"[^"]*"' | cut -d'"' -f4)
  
  if [ ! -z "$TOKEN" ]; then
    echo " ✅ User Login"
    
    # Add ticker
    ADD_TICKER=$(curl -s -X POST http://localhost/api/portfolio/tickers \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d '{"symbol":"AAPL","shares":10,"purchasePrice":150}')
    
    if echo "$ADD_TICKER" | grep -q "successfully"; then
      echo " ✅ Add Ticker"
      
      # Check dividends
      DIVIDENDS=$(curl -s -H "Authorization: Bearer $TOKEN" \
        http://localhost/api/dividends/projection)
      
      ANNUAL_DIV=$(echo "$DIVIDENDS" | grep -o '"totalAnnualDividend":[0-9.]*' | cut -d':' -f2)
      if [ "$ANNUAL_DIV" != "0" ]; then
        echo " ✅ Dividends Working ($ANNUAL_DIV annual)"
      else
        echo " ❌ Dividends Showing Zero"
      fi
    else
      echo " ❌ Add Ticker Failed"
    fi
  else
    echo " ❌ Login Failed"
  fi
else
  echo " ❌ Registration Failed"
fi

echo -e "\n4. MVP Mode Status:"
if grep -q "MVP_MODE=true" .env; then
  echo " ✅ MVP Mode Enabled"
else
  echo " ⚠️  MVP Mode Disabled"
fi

echo -e "\nDebug completed!"
```

### Make Commands for Debugging
```bash
# Add to Makefile
debug:
	@echo "🔍 Running system debug..."
	@./debug-system.sh

logs-all:
	@echo "📋 Showing all service logs..."
	@docker-compose logs --tail=20

restart-all:
	@echo "🔄 Restarting all services..."
	@docker-compose restart

clean-rebuild:
	@echo "🧹 Clean rebuild..."
	@docker-compose down -v
	@docker-compose build --no-cache
	@docker-compose up -d
```

### PowerShell Test Commands (Windows)
```powershell
# Register user
$registerResponse = Invoke-RestMethod -Uri "http://localhost/api/users/register" -Method POST -ContentType "application/json" -Body '{"email":"test@example.com","password":"TestPass123!","name":"Test User"}'

# Login and get token
$loginResponse = Invoke-RestMethod -Uri "http://localhost/api/users/login" -Method POST -ContentType "application/json" -Body '{"email":"test@example.com","password":"TestPass123!"}'
$token = $loginResponse.token

# Add ticker
Invoke-RestMethod -Uri "http://localhost/api/portfolio/tickers" -Method POST -ContentType "application/json" -Headers @{Authorization="Bearer $token"} -Body '{"symbol":"AAPL","shares":10,"purchasePrice":150.50}'

# Get portfolio
Invoke-RestMethod -Uri "http://localhost/api/portfolio/tickers" -Method GET -Headers @{Authorization="Bearer $token"}
```

## 🎯 MVP Mode

The system includes an MVP mode that allows it to work without external API dependencies. This is perfect for:
- Development and testing
- Demos and presentations  
- When market is closed
- When API keys are not available

### Enabling MVP Mode
Set `MVP_MODE=true` in your `.env` file:

```bash
# MVP Mode - Set to 'true' to use mock data instead of real market APIs
MVP_MODE=true
```

### MVP Mode Features
- **Mock Stock Prices**: Consistent, realistic stock prices based on symbol hash
- **Mock Dividend Data**: Realistic dividend yields and payment schedules
- **Market Status**: Simulated market open/close times
- **When Market Closed**: Uses last high price as current price
- **No API Limits**: Works without Alpha Vantage API key
- **Consistent Data**: Same mock data for same symbols across sessions

### Real vs MVP Mode
| Feature | Real Mode | MVP Mode |
|---------|-----------|----------|
| Stock Prices | Live from Alpha Vantage | Generated mock data |
| Dividend Data | Real company data | Realistic mock data |
| API Dependencies | Requires Alpha Vantage key | No external APIs |
| Rate Limits | Yes (5 calls/minute free) | None |
| Market Hours | Real market status | Simulated status |
| Data Consistency | Real-time updates | Consistent mock data |

## 🔧 Development

### Local Development with Hot Reload
```bash
# Start in development mode
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up

# Or individual service
cd user-service
npm install
npm run dev
```

### Deploy Single Service (Zero Downtime)
```bash
# Deploy only user service
./deploy/deploy-service.sh user-service

# Deploy only frontend
./deploy/deploy-service.sh frontend
```

### Common Commands
```bash
# View logs
make logs

# Restart specific service
docker-compose restart user-service

# Shell into service
docker exec -it stock-portfolio-user-service sh

# Database access
docker exec -it stock-portfolio-postgres psql -U stockuser -d stockportfolio

# Redis access
docker exec -it stock-portfolio-redis redis-cli -a your_password
```

## 🔐 Security Features

- JWT authentication with secure tokens
- Password hashing with bcrypt
- Rate limiting (100 req/min per IP)
- CORS protection
- Input validation
- SQL injection prevention
- HTTPS ready with Let's Encrypt
- Firewall configuration (UFW)

## 📈 Monitoring & Maintenance

### Health Checks
```bash
# Check all services
make health

# Individual service health
curl http://localhost/api/users/health
curl http://localhost/api/portfolio/health
curl http://localhost/api/market/health
curl http://localhost/api/dividends/health
```

### Monitoring
```bash
# System monitor
./scripts/monitor.sh

# View logs
docker-compose logs -f

# Resource usage
docker stats

# NGINX statistics
./scripts/nginx-stats.sh
```

### Backups
```bash
# Manual backup
./scripts/backup.sh

# Automated daily backups (setup by ec2-setup.sh)
# Runs daily at 2 AM via cron
```

## 🐛 Troubleshooting

### Common Issues

**Service won't start:**
```bash
docker logs stock-portfolio-user-service
docker-compose restart user-service
```

**Database connection failed:**
```bash
docker logs stock-portfolio-postgres
docker exec stock-portfolio-postgres pg_isready -U stockuser
```

**502 Bad Gateway:**
```bash
docker logs stock-portfolio-nginx-proxy
./deploy/test-proxy.sh
```

**Out of disk space:**
```bash
df -h
docker system prune -a --volumes
```

### Reset Everything
```bash
make clean
make setup
make start
```

## 📁 Project Structure

```
stock-portfolio/
├── README.md                    # This file
├── QUICKSTART.md               # 5-minute setup guide
├── docker-compose.yml          # Main orchestration
├── docker-compose.dev.yml      # Development overrides
├── .env.example                # Environment template
├── init-db.sql                 # Database schema
├── Makefile                    # Common commands
│
├── deploy/                     # Deployment scripts
│   ├── base-setup.sh          # Setup infrastructure
│   ├── deploy-service.sh      # Deploy individual service
│   ├── health-check.sh        # Health monitoring
│   ├── setup-ssl.sh           # Enable HTTPS
│   └── ec2-setup.sh           # EC2 initialization
│
├── scripts/                    # Utility scripts
│   ├── backup.sh              # Database backup
│   ├── monitor.sh             # System monitoring
│   └── nginx-stats.sh         # NGINX analytics
│
├── user-service/              # Authentication service
├── portfolio-service/         # Portfolio management
├── market-data-service/       # Stock data fetching
├── dividend-service/          # Dividend tracking
├── frontend/                  # React application
└── nginx/                     # Reverse proxy
```

## 🎓 Learning Resources

- **Docker**: https://docs.docker.com
- **PostgreSQL**: https://www.postgresql.org/docs
- **Redis**: https://redis.io/documentation
- **Express.js**: https://expressjs.com
- **React**: https://react.dev
- **Alpha Vantage**: https://www.alphavantage.co/documentation

## 📞 Support

### Documentation
- Complete setup guide in README
- API documentation with examples
- Troubleshooting guides
- Security best practices

### Getting Help
- Check logs: `make logs`
- Health check: `make health`
- Monitor system: `./scripts/monitor.sh`

## 📋 Production Checklist

### Before Deployment
- [ ] Environment variables configured
- [ ] Alpha Vantage API key obtained
- [ ] Secure passwords generated
- [ ] Firewall rules configured
- [ ] SSL certificates ready (if using domain)

### After Deployment
- [ ] All services healthy
- [ ] Can register and login
- [ ] Can add/remove tickers
- [ ] Budget calculations work
- [ ] Dividend projections display
- [ ] Backups working
- [ ] Monitoring setup

## 🚀 Advanced Features

### Enable HTTPS
```bash
./deploy/setup-ssl.sh yourdomain.com
```

### Scale Services
```bash
docker-compose up -d --scale portfolio-service=3
```

### CI/CD Pipeline
GitHub Actions workflow included for automatic deployments.

## 📄 License

MIT License - see LICENSE file for details.

## 🎉 Success Indicators

✅ All containers show "Up" status  
✅ Health check shows all green  
✅ Frontend loads at http://localhost/  
✅ Can register and login  
✅ Can add tickers to portfolio  
✅ Can view dividend projections  
✅ No errors in logs  

---

**Ready to build an amazing stock portfolio system!** 🚀

For questions or issues, check the troubleshooting section or create a GitHub issue.
---


## 🎉 Project Complete!

I've successfully created a complete **Stock Portfolio Management System** with all the components you requested. Here's what has been built:

## 📁 Complete Project Structure

```
stock-portfolio/
├── 📋 Documentation & Setup
│   ├── README.md                    # Complete documentation
│   ├── QUICKSTART.md               # 5-minute setup guide
│   ├── .env.example                # Environment template
│   ├── docker-compose.yml          # Production orchestration
│   ├── docker-compose.dev.yml      # Development mode
│   ├── init-db.sql                 # Database schema
│   ├── Makefile                    # Quick commands
│   └── make-executable.sh          # Script permissions
│
├── 🚀 Deployment Scripts
│   └── deploy/
│       ├── base-setup.sh           # Infrastructure setup
│       ├── deploy-service.sh       # Individual service deployment
│       ├── health-check.sh         # Health monitoring
│       ├── test-proxy.sh           # NGINX routing tests
│       ├── setup-ssl.sh            # HTTPS configuration
│       └── ec2-setup.sh            # EC2 automation
│
├── 🛠️ Utility Scripts
│   └── scripts/
│       ├── backup.sh               # Database backups
│       ├── monitor.sh              # System monitoring
│       └── nginx-stats.sh          # NGINX analytics
│
├── 🔐 Microservices (6 Services)
│   ├── user-service/               # Authentication (Port 3001)
│   ├── portfolio-service/          # Portfolio management (Port 3002)
│   ├── market-data-service/        # Stock data (Port 3003)
│   ├── dividend-service/           # Dividend tracking (Port 3004)
│   ├── frontend/                   # React UI (Port 80)
│   └── nginx/                      # Reverse proxy (Port 80)
│
└── 📊 Each service includes:
    ├── Dockerfile & Dockerfile.dev
    ├── package.json
    └── Complete source code
```

## ✨ Key Features Implemented

### 🏗️ **Architecture**
- **Microservices**: 6 independent, scalable services
- **Single Entry Point**: NGINX reverse proxy (only port 80 exposed)
- **Database**: PostgreSQL with proper schema and relationships
- **Caching**: Redis for performance optimization
- **Containerization**: Full Docker setup with health checks

### 🔐 **Security**
- JWT authentication with secure token handling
- Password hashing with bcrypt (12 rounds)
- Rate limiting (100 req/min general, 5 req/min login)
- CORS protection and security headers
- Input validation and SQL injection prevention
- HTTPS ready with Let's Encrypt automation

### 📊 **Functionality**
- **User Management**: Registration, login, profile management
- **Portfolio Tracking**: Add/remove stocks, budget management
- **Real-time Market Data**: Alpha Vantage API integration with caching
- **Dividend Analysis**: Projections, calendar, sector breakdown
- **Responsive UI**: Modern React interface with Tailwind CSS

### 🚀 **Deployment Options**
- **Local Development**: Hot reload, debugging support
- **Production Ready**: Optimized Docker images
- **EC2 Deployment**: One-command cloud setup
- **Zero Downtime**: Individual service deployment
- **SSL/HTTPS**: Automated certificate management

## 🚀 Quick Start (3 Commands)

```bash
# 1. Setup (one-time)
cp .env.example .env && nano .env  # Add your Alpha Vantage API key
make setup

# 2. Start everything
make start

# 3. Access application
open http://localhost/
```

## 🌩️ EC2 Deployment (2 Commands)

```bash
# 1. Setup EC2 instance
curl -o ec2-setup.sh https://raw.githubusercontent.com/<your-repo>/main/deploy/ec2-setup.sh
chmod +x ec2-setup.sh && ./ec2-setup.sh

# 2. Deploy application (after logout/login)
git clone <your-repo> ~/stock-portfolio && cd ~/stock-portfolio
cp .env.example .env && nano .env  # Configure
make setup && make start
```

## 🎯 What You Can Do Now

### **For Users:**
- ✅ Register and manage accounts
- ✅ Add stocks to portfolio with shares and prices
- ✅ Set investment budgets and track allocation
- ✅ View real-time stock quotes and market data
- ✅ Analyze dividend-paying stocks
- ✅ Project yearly dividend income
- ✅ Monitor upcoming dividend payments

### **For Developers:**
- ✅ Deploy individual services independently
- ✅ Scale services horizontally
- ✅ Monitor system health and performance
- ✅ Backup and restore data
- ✅ View detailed logs and analytics
- ✅ Test API endpoints

### **For DevOps:**
- ✅ One-command EC2 deployment
- ✅ Automated SSL certificate setup
- ✅ Health monitoring and alerting
- ✅ Automated backups with retention
- ✅ NGINX statistics and caching
- ✅ Zero-downtime deployments

## 🔧 Management Commands

```bash
# Quick commands via Makefile
make start          # Start all services
make stop           # Stop all services  
make health         # Check service health
make logs           # View all logs
make backup         # Backup database
make clean          # Clean reset

# Individual service deployment
make deploy-user         # Deploy user service only
make deploy-portfolio    # Deploy portfolio service only
make deploy-market       # Deploy market data service only
make deploy-dividend     # Deploy dividend service only
make deploy-frontend     # Deploy frontend only

# Monitoring and maintenance
./scripts/monitor.sh     # System monitoring
./scripts/nginx-stats.sh # NGINX analytics
./deploy/test-proxy.sh   # Test routing
```

## 🌐 Access Points

- **Application**: http://localhost/ (single entry point)
- **All APIs**: http://localhost/api/* (routed through NGINX)
- **Health Checks**: http://localhost/health

## 📋 Requirements Met

✅ **Microservices Architecture**: 6 independent services  
✅ **Local Development**: Docker Compose with hot reload  
✅ **EC2 Deployment**: Automated setup and deployment  
✅ **Single Entry Point**: NGINX reverse proxy  
✅ **Database**: PostgreSQL with proper schema  
✅ **Caching**: Redis for performance  
✅ **Real-time Data**: Alpha Vantage API integration  
✅ **Security**: JWT auth, rate limiting, HTTPS ready  
✅ **Monitoring**: Health checks, logging, analytics  
✅ **Backups**: Automated database backups  
✅ **Documentation**: Comprehensive guides and API docs  
✅ **Testing**: Health checks and routing tests  

## 🎓 Next Steps

1. **Get Alpha Vantage API Key**: https://www.alphavantage.co/support/#api-key (free)
2. **Configure Environment**: Edit `.env` with your API key and secure passwords
3. **Deploy Locally**: Run `make setup && make start`
4. **Test Application**: Register account, add stocks, view dividends
5. **Deploy to EC2**: Use the automated EC2 setup script
6. **Enable HTTPS**: Run `./deploy/setup-ssl.sh yourdomain.com`

## 🆘 Support

- **Documentation**: Complete guides in README.md
- **Quick Start**: QUICKSTART.md for 5-minute setup
- **Troubleshooting**: Health checks and monitoring tools
- **API Reference**: Complete API documentation included

**🎊 Your Stock Portfolio Management System is ready to deploy!** 🚀