# Stock Portfolio System - Complete Deployment Summary

## 🎯 What You Have

A production-ready microservices architecture with:

### Services (6 Independent Microservices)
1. **User Service** - Authentication & user management
2. **Portfolio Service** - Stock portfolio & budget management
3. **Market Data Service** - Real-time stock prices (Alpha Vantage)
4. **Dividend Service** - Dividend tracking & yearly projections
5. **Frontend** - React web application
6. **API Gateway** - NGINX reverse proxy

### Infrastructure
- **PostgreSQL** - Primary database
- **Redis** - Caching layer
- **Docker** - Containerization
- **Docker Compose** - Orchestration

## 📁 Complete File Structure

```
stock-portfolio/
├── README.md
├── QUICKSTART.md
├── docker-compose.yml
├── docker-compose.dev.yml
├── .env.example
├── .env (you create this)
├── .gitignore
├── init-db.sql
├── Makefile
│
├── deploy/
│   ├── base-setup.sh              # Setup infrastructure
│   ├── deploy-service.sh          # Deploy single service
│   ├── rollback-service.sh        # Rollback service
│   ├── health-check.sh            # Health monitoring
│   └── ec2-setup.sh               # EC2 initial setup
│
├── user-service/
│   ├── Dockerfile
│   ├── package.json
│   └── src/
│       └── index.js
│
├── portfolio-service/
│   ├── Dockerfile
│   ├── package.json
│   └── src/
│       └── index.js
│
├── market-data-service/
│   ├── Dockerfile
│   ├── package.json
│   └── src/
│       └── index.js
│
├── dividend-service/
│   ├── Dockerfile
│   ├── package.json
│   └── src/
│       └── index.js
│
├── frontend/
│   ├── Dockerfile
│   ├── package.json
│   ├── nginx.conf
│   └── src/
│       ├── App.js
│       ├── index.js
│       ├── components/
│       ├── services/
│       └── utils/
│
├── nginx/
│   ├── Dockerfile
│   └── nginx.conf
│
├── .github/workflows/
│   └── deploy.yml                 # CI/CD pipeline
│
├── backups/                       # Database backups
└── logs/                          # Application logs
```

## 🚀 Deployment Steps

### Local Development

```bash
# 1. Setup
git clone <your-repo>
cd stock-portfolio
cp .env.example .env
# Edit .env with your values

# 2. Initialize
chmod +x deploy/*.sh
./deploy/base-setup.sh

# 3. Deploy all services
docker-compose up -d

# 4. Verify
./deploy/health-check.sh
```

Access: http://localhost:3005

### EC2 Production Deployment

```bash
# 1. SSH to EC2
ssh -i your-key.pem ubuntu@<EC2-IP>

# 2. Run setup script
curl -o ec2-setup.sh <your-raw-github-url>/deploy/ec2-setup.sh
chmod +x ec2-setup.sh
./ec2-setup.sh

# 3. Logout and login (for Docker group)
exit
ssh -i your-key.pem ubuntu@<EC2-IP>

# 4. Clone and deploy
git clone <your-repo> ~/stock-portfolio
cd ~/stock-portfolio
cp .env.example .env
nano .env  # Configure

./deploy/base-setup.sh
docker-compose up -d
```

Access: http://<EC2-PUBLIC-IP>:3005

## 🔧 Independent Service Deployment

### Deploy Single Service

```bash
# Deploy only user service
./deploy/deploy-service.sh user-service

# Deploy only portfolio service
./deploy/deploy-service.sh portfolio-service

# Deploy only market data service
./deploy/deploy-service.sh market-data-service

# Deploy only dividend service
./deploy/deploy-service.sh dividend-service

# Deploy only frontend
./deploy/deploy-service.sh frontend
```

### Using Makefile

```bash
make deploy-user         # Deploy user service
make deploy-portfolio    # Deploy portfolio service
make deploy-market       # Deploy market data service
make deploy-dividend     # Deploy dividend service
make deploy-frontend     # Deploy frontend

make health              # Check health
make logs                # View logs
make backup              # Backup database
```

## 🔐 Environment Variables Setup

### Option 1: .env File (Recommended for Development)

```bash
cp .env.example .env
nano .env

# Set:
POSTGRES_PASSWORD=your_secure_password
REDIS_PASSWORD=your_redis_password
JWT_SECRET=your_long_random_secret
ALPHA_VANTAGE_API_KEY=your_api_key
```

### Option 2: EC2 Environment Variables (Recommended for Production)

```bash
# Add to ~/.bashrc
nano ~/.bashrc

# Add at end:
export POSTGRES_PASSWORD=your_secure_password
export REDIS_PASSWORD=your_redis_password
export JWT_SECRET=your_jwt_secret
export ALPHA_VANTAGE_API_KEY=your_api_key
# ... (add all variables)

# Load
source ~/.bashrc
```

### Option 3: AWS Systems Manager (Most Secure)

```bash
# Store secrets
aws ssm put-parameter \
  --name /stock-portfolio/postgres-password \
  --value "your_password" \
  --type SecureString

aws ssm put-parameter \
  --name /stock-portfolio/jwt-secret \
  --value "your_jwt_secret" \
  --type SecureString

# Retrieve in scripts
export POSTGRES_PASSWORD=$(aws ssm get-parameter \
  --name /stock-portfolio/postgres-password \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text)
```

## 📊 Service Ports

| Service | Port | Purpose |
|---------|------|---------|
| Frontend | 3005 | Web UI |
| API Gateway | 3000 | Request routing |
| User Service | 3001 | Authentication |
| Portfolio Service | 3002 | Portfolio management |
| Market Data Service | 3003 | Stock data |
| Dividend Service | 3004 | Dividends |
| PostgreSQL | 5432 | Database |
| Redis | 6379 | Cache |

## 🔍 Monitoring & Management

### Health Checks

```bash
# Check all services
./deploy/health-check.sh

# Individual service
curl http://localhost:3001/health
curl http://localhost:3002/health
curl http://localhost:3003/health
curl http://localhost:3004/health
```

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker logs -f stock-portfolio-user-service
docker logs -f stock-portfolio-portfolio-service

# Last 100 lines
docker logs --tail 100 stock-portfolio-user-service

# Since 1 hour ago
docker logs --since 1h stock-portfolio-user-service
```

### Resource Monitoring

```bash
# Real-time stats
docker stats

# Disk usage
df -h

# Container status
docker ps

# Memory usage per service
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

### Database Management

```bash
# Connect to database
docker exec -it stock-portfolio-postgres psql -U stockuser -d stockportfolio

# Backup database
docker exec stock-portfolio-postgres pg_dump -U stockuser stockportfolio > backup.sql

# Restore database
docker exec -i stock-portfolio-postgres psql -U stockuser stockportfolio < backup.sql

# Check database size
docker exec stock-portfolio-postgres psql -U stockuser -d stockportfolio -c "\l+"

# List tables
docker exec stock-portfolio-postgres psql -U stockuser -d stockportfolio -c "\dt"
```

### Redis Management

```bash
# Connect to Redis
docker exec -it stock-portfolio-redis redis-cli -a your_password

# Check cache keys
docker exec stock-portfolio-redis redis-cli -a your_password KEYS "*"

# Clear cache
docker exec stock-portfolio-redis redis-cli -a your_password FLUSHALL

# Monitor Redis
docker exec stock-portfolio-redis redis-cli -a your_password MONITOR
```

## 🔄 Update & Rollback Procedures

### Update Single Service

```bash
# 1. Make code changes
cd user-service/src
nano index.js

# 2. Commit changes
git add .
git commit -m "Update user service"
git push

# 3. On server, pull and deploy
cd ~/stock-portfolio
git pull origin main
./deploy/deploy-service.sh user-service

# 4. Verify
curl http://localhost:3001/health
docker logs stock-portfolio-user-service
```

### Rollback Service

```bash
# Rollback to previous version
./deploy/rollback-service.sh user-service previous

# Rollback to specific tag
./deploy/rollback-service.sh user-service v1.2.0
```

### Zero-Downtime Deployment

```bash
# Services continue running during update
# Only the updating service has brief downtime

# Example: Update portfolio service without affecting others
./deploy/deploy-service.sh portfolio-service

# Other services (user, market-data, dividend, frontend) remain operational
```

## 🛡️ Security Checklist

- [ ] Change all default passwords in .env
- [ ] Use strong JWT secret (min 64 characters)
- [ ] Enable firewall (UFW) on EC2
- [ ] Configure security groups properly
- [ ] Use HTTPS in production (SSL certificates)
- [ ] Never commit .env to git
- [ ] Use environment variables for secrets
- [ ] Regular security updates: `apt update && apt upgrade`
- [ ] Implement rate limiting
- [ ] Enable database backups
- [ ] Monitor logs for suspicious activity
- [ ] Use AWS Secrets Manager or SSM for production

## 🐛 Troubleshooting

### Service Won't Start

```bash
# Check logs
docker logs stock-portfolio-user-service

# Check if port is in use
sudo netstat -tulpn | grep 3001

# Restart service
docker-compose restart user-service

# Full restart
docker-compose down
docker-compose up -d
```

### Database Connection Issues

```bash
# Check if PostgreSQL is running
docker ps | grep postgres

# Test connection
docker exec stock-portfolio-postgres pg_isready -U stockuser

# Check logs
docker logs stock-portfolio-postgres

# Restart PostgreSQL
docker-compose restart postgres
```

### Redis Connection Issues

```bash
# Check Redis
docker ps | grep redis

# Test connection
docker exec stock-portfolio-redis redis-cli -a your_password ping

# Check logs
docker logs stock-portfolio-redis

# Restart Redis
docker-compose restart redis
```

### API Gateway Issues

```bash
# Check NGINX logs
docker logs stock-portfolio-api-gateway

# Test routing
curl http://localhost:3000/api/users/health

# Restart gateway
docker-compose restart api-gateway
```

### Out of Disk Space

```bash
# Check disk usage
df -h

# Clean Docker
docker system prune -a --volumes

# Remove old logs
find logs/ -name "*.log" -mtime +30 -delete

# Remove old backups
find backups/ -name "*.sql" -mtime +30 -delete
```

### Memory Issues

```bash
# Check memory
free -h

# Check Docker stats
docker stats

# Increase swap (if needed)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

## 📈 Performance Optimization

### Database Optimization

```sql
-- Connect to database
docker exec -it stock-portfolio-postgres psql -U stockuser -d stockportfolio

-- Analyze tables
ANALYZE users;
ANALYZE portfolio;
ANALYZE budget;

-- Vacuum database
VACUUM ANALYZE;

-- Check slow queries
SELECT query, mean_exec_time 
FROM pg_stat_statements 
ORDER BY mean_exec_time DESC 
LIMIT 10;
```

### Redis Optimization

```bash
# Check cache hit rate
docker exec stock-portfolio-redis redis-cli -a your_password INFO stats | grep hits

# Optimize memory
docker exec stock-portfolio-redis redis-cli -a your_password CONFIG SET maxmemory 256mb
docker exec stock-portfolio-redis redis-cli -a your_password CONFIG SET maxmemory-policy allkeys-lru
```

### Scale Services Horizontally

```bash
# Scale portfolio service to 3 instances
docker-compose up -d --scale portfolio-service=3

# Update NGINX to load balance
# Edit nginx/nginx.conf to add multiple upstream servers
```

## 🔐 Backup Strategy

### Automated Daily Backups

```bash
# Cron job (already setup by ec2-setup.sh)
# Runs daily at 2 AM
0 2 * * * /home/ubuntu/stock-portfolio/backup.sh

# Manual backup
./backup.sh

# Or directly
docker exec stock-portfolio-postgres pg_dump -U stockuser stockportfolio > backups/backup_$(date +%Y%m%d).sql
```

### Backup to S3 (Recommended for Production)

```bash
# Install AWS CLI
sudo apt install awscli -y
aws configure

# Backup script with S3
cat > backup-to-s3.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="backup_${DATE}.sql"

# Backup database
docker exec stock-portfolio-postgres pg_dump -U stockuser stockportfolio > /tmp/${BACKUP_FILE}

# Compress
gzip /tmp/${BACKUP_FILE}

# Upload to S3
aws s3 cp /tmp/${BACKUP_FILE}.gz s3://your-bucket/backups/

# Clean local file
rm /tmp/${BACKUP_FILE}.gz

echo "Backup completed: ${BACKUP_FILE}.gz"
EOF

chmod +x backup-to-s3.sh

# Add to cron
crontab -e
# Add: 0 2 * * * /home/ubuntu/stock-portfolio/backup-to-s3.sh
```

## 📊 API Usage Examples

### Register User

```bash
curl -X POST http://localhost:3000/api/users/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "john@example.com",
    "password": "SecurePass123!",
    "name": "John Doe"
  }'
```

### Login

```bash
TOKEN=$(curl -X POST http://localhost:3000/api/users/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "john@example.com",
    "password": "SecurePass123!"
  }' | jq -r '.token')

echo $TOKEN
```

### Add Ticker

```bash
curl -X POST http://localhost:3000/api/portfolio/tickers \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "symbol": "AAPL",
    "shares": 10,
    "purchasePrice": 150.50
  }'
```

### Get Portfolio

```bash
curl -X GET http://localhost:3000/api/portfolio/tickers \
  -H "Authorization: Bearer $TOKEN"
```

### Set Budget

```bash
curl -X PUT http://localhost:3000/api/portfolio/budget \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "totalBudget": 10000
  }'
```

### Get Dividend Projection

```bash
curl -X GET http://localhost:3000/api/dividends/projection \
  -H "Authorization: Bearer $TOKEN"
```

### Get Stock Quote

```bash
curl -X GET http://localhost:3000/api/market/quote/AAPL \
  -H "Authorization: Bearer $TOKEN"
```

## 🎯 Production Checklist

### Before Going Live

- [ ] All services healthy and running
- [ ] Database properly initialized
- [ ] Environment variables configured
- [ ] Firewall rules configured
- [ ] SSL certificates installed (if using domain)
- [ ] Backup system tested
- [ ] Monitoring setup (health checks)
- [ ] Log rotation configured
- [ ] Resource limits set in docker-compose
- [ ] Security group properly configured
- [ ] API rate limiting enabled
- [ ] Error handling tested
- [ ] Documentation complete
- [ ] CI/CD pipeline working (if using)

### Post-Deployment

- [ ] Test all API endpoints
- [ ] Verify user registration and login
- [ ] Test adding/removing tickers
- [ ] Verify budget calculations
- [ ] Test dividend projections
- [ ] Check logs for errors
- [ ] Monitor resource usage
- [ ] Verify backups working
- [ ] Test service restarts
- [ ] Verify data persistence

## 📞 Support & Maintenance

### Daily Tasks
- Check service health: `./deploy/health-check.sh`
- Review error logs
- Monitor disk space: `df -h`

### Weekly Tasks
- Review all logs
- Check resource usage: `docker stats`
- Update dependencies (security patches)
- Review backup integrity

### Monthly Tasks
- Full system backup
- Database optimization (VACUUM, ANALYZE)
- Review and rotate logs
- Security audit
- Update system packages

### Emergency Contacts
- Database issues: Check PostgreSQL logs
- Service crashes: Check Docker logs
- High load: Scale services horizontally
- Security issues: Review NGINX access logs

## 🚀 Advanced Features

### Enable HTTPS with Let's Encrypt

```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx -y

# Get certificate
sudo certbot --nginx -d your-domain.com

# Auto-renewal
sudo certbot renew --dry-run
```

### Setup Monitoring with Prometheus

```yaml
# Add to docker-compose.yml
prometheus:
  image: prom/prometheus
  volumes:
    - ./prometheus.yml:/etc/prometheus/prometheus.yml
  ports:
    - "9090:9090"

grafana:
  image: grafana/grafana
  ports:
    - "3001:3000"
  depends_on:
    - prometheus
```

### Add Logging with ELK Stack

```yaml
elasticsearch:
  image: elasticsearch:8.8.0
  environment:
    - discovery.type=single-node

logstash:
  image: logstash:8.8.0
  volumes:
    - ./logstash.conf:/usr/share/logstash/pipeline/logstash.conf

kibana:
  image: kibana:8.8.0
  ports:
    - "5601:5601"
```

## 📝 License & Credits

- Project: Stock Portfolio Management System
- License: MIT
- Author: Your Name
- Technologies: Node.js, React, PostgreSQL, Redis, Docker, NGINX

## 🎓 Learning Resources

- Docker: https://docs.docker.com
- PostgreSQL: https://www.postgresql.org/docs
- Redis: https://redis.io/documentation
- Express.js: https://expressjs.com
- React: https://react.dev
- Alpha Vantage: https://www.alphavantage.co/documentation

---

**Quick Commands Reference:**

```bash
# Start everything
make start

# Stop everything
make stop

# View logs
make logs

# Health check
make health

# Deploy service
make deploy-user

# Backup database
make backup

# Clean everything
make clean
```

**Need Help?** Check the complete documentation in the README and troubleshooting guides!