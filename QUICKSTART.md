# 🚀 Quick Start Guide (5 Minutes)

Get your Stock Portfolio Management System running in 5 minutes!

## Prerequisites

- Docker & Docker Compose installed
- Alpha Vantage API key (free): https://www.alphavantage.co/support/#api-key
  - **Optional**: System works in MVP mode with mock data if no API key provided

## Step 1: Clone and Setup

```bash
git clone <your-repo-url>
cd stock-portfolio
cp .env.example .env
```

## Step 2: Configure Environment

Edit `.env` file and set these required values:

```bash
nano .env
```

**Required Configuration:**
```bash
# Get free API key from Alpha Vantage (optional - uses mock data if not provided)
ALPHA_VANTAGE_API_KEY=your_api_key_here

# MVP Mode - Set to 'true' to use mock data (great for testing/demos)
MVP_MODE=true

# Generate secure passwords
POSTGRES_PASSWORD=your_secure_password
REDIS_PASSWORD=your_redis_password
JWT_SECRET=your_long_random_secret
```

**Generate Secure Values:**
```bash
# PostgreSQL password
openssl rand -base64 32

# Redis password
openssl rand -base64 32

# JWT secret (64+ characters)
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
```

## Step 3: Deploy

```bash
# Make scripts executable
chmod +x deploy/*.sh scripts/*.sh

# Setup infrastructure (PostgreSQL, Redis, NGINX)
make setup

# Start all services
make start

# Check health
make health
```

## Step 4: Access Application

- **Frontend**: http://localhost/
- **API**: http://localhost/api/

## Step 5: Test the System

### Manual Testing
1. **Register**: Create new account
2. **Login**: Sign in with credentials
3. **Add Ticker**: Add "AAPL" with 10 shares at $150
4. **Set Budget**: Set total budget to $10,000
5. **View Dividends**: Check dividend projections

### Automated MVP Testing
```bash
# Test all MVP mode functionality
make test-mvp
```

This will verify:
- Mock stock prices are working
- Dividend calculations are correct
- Buy/sell functionality works
- All services are responding properly

## Common Commands

```bash
# View logs
make logs

# Restart service
docker-compose restart user-service

# Stop everything
make stop

# Clean restart
make clean && make setup && make start

# Deploy single service
./deploy/deploy-service.sh user-service

# Monitor system
./scripts/monitor.sh
```

## Troubleshooting

### Service Won't Start
```bash
# Check logs
docker logs stock-portfolio-user-service

# Restart service
docker-compose restart user-service
```

### Database Issues
```bash
# Check PostgreSQL
docker logs stock-portfolio-postgres

# Test connection
docker exec stock-portfolio-postgres pg_isready -U stockuser
```

### API Not Working
```bash
# Check NGINX proxy
docker logs stock-portfolio-nginx-proxy

# Test routing
./deploy/test-proxy.sh
```

### Docker Build Issues
```bash
# If you get npm ci errors
make fix

# Clean reset
make clean
make setup
make start
```

## EC2 Deployment

### Quick EC2 Setup
```bash
# On EC2 instance (Ubuntu 22.04)
curl -o ec2-setup.sh https://raw.githubusercontent.com/<your-repo>/main/deploy/ec2-setup.sh
chmod +x ec2-setup.sh
./ec2-setup.sh

# Logout and login for Docker group
exit
ssh -i your-key.pem ubuntu@<EC2-IP>

# Clone and deploy
git clone <your-repo> ~/stock-portfolio
cd ~/stock-portfolio
cp .env.example .env
nano .env  # Configure production values
make setup && make start
```

### Access Production
- **Application**: http://your-ec2-ip/
- **Enable HTTPS**: `./deploy/setup-ssl.sh yourdomain.com`

## Success Indicators

✅ `make health` shows all services healthy  
✅ Frontend loads at http://localhost/  
✅ Can register new account  
✅ Can login successfully  
✅ Can add stock tickers  
✅ Can set budget  
✅ Can view dividend projections  

## Next Steps

- Read full README.md for detailed documentation
- Check API documentation for integration
- Setup monitoring and backups
- Configure HTTPS for production
- Setup CI/CD pipeline

**You're ready to go! 🎉**