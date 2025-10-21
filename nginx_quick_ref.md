# NGINX Reverse Proxy - Quick Reference Card

## 🚀 One-Line Deployment

```bash
# Deploy everything with single entry point
docker-compose up -d && ./test-proxy.sh
```

## 🌐 Access URLs

| Service | Old URL (Multiple Ports) | New URL (Single Domain) |
|---------|-------------------------|------------------------|
| **Frontend** | http://ip:3005 | http://ip/ |
| **User API** | http://ip:3001/api/users | http://ip/api/users |
| **Portfolio API** | http://ip:3002/api/portfolio | http://ip/api/portfolio |
| **Market API** | http://ip:3003/api/market | http://ip/api/market |
| **Dividend API** | http://ip:3004/api/dividends | http://ip/api/dividends |
| **Health Check** | http://ip:3000/health | http://ip/health |

## 🔧 Essential Commands

```bash
# Restart NGINX proxy only
docker-compose restart nginx-proxy

# View NGINX logs
docker logs -f stock-portfolio-nginx-proxy

# Test NGINX configuration
docker exec stock-portfolio-nginx-proxy nginx -t

# Reload NGINX (without restart)
docker exec stock-portfolio-nginx-proxy nginx -s reload

# Check all routes
./test-proxy.sh

# Monitor access log
docker exec stock-portfolio-nginx-proxy tail -f /var/log/nginx/access.log
```

## 🔒 Security Group (AWS EC2)

```
ONLY KEEP THESE PORTS OPEN:
✅ Port 22  (SSH)
✅ Port 80  (HTTP)
✅ Port 443 (HTTPS)

REMOVE THESE:
❌ Port 3000-3005 (Individual services)
```

## 🎯 API Examples with Single Domain

```bash
# Set base URL (no port needed!)
BASE_URL="http://your-ip-or-domain"

# Register user
curl -X POST $BASE_URL/api/users/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"Test123!","name":"Test"}'

# Login
TOKEN=$(curl -X POST $BASE_URL/api/users/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"Test123!"}' | jq -r '.token')

# Add ticker
curl -X POST $BASE_URL/api/portfolio/tickers \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"symbol":"AAPL","shares":10,"purchasePrice":150}'

# Get portfolio
curl $BASE_URL/api/portfolio/tickers \
  -H "Authorization: Bearer $TOKEN"

# Get dividends
curl $BASE_URL/api/dividends/projection \
  -H "Authorization: Bearer $TOKEN"

# Get stock quote
curl $BASE_URL/api/market/quote/AAPL \
  -H "Authorization: Bearer $TOKEN"
```

## 🔐 Enable HTTPS (SSL)

```bash
# One-command SSL setup
./deploy/setup-ssl.sh yourdomain.com

# Access with HTTPS
https://yourdomain.com/
```

## 📊 Monitoring

```bash
# Quick health check
curl http://localhost/health

# Detailed stats
./nginx-stats.sh

# Real-time monitoring
watch -n 2 'curl -s http://localhost/health'

# Check all services
for svc in users portfolio market dividends; do
  echo "$svc: $(curl -s http://localhost/api/$svc/health)"
done
```

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| **502 Bad Gateway** | `docker-compose restart <service-name>` |
| **404 Not Found** | Check URL path has `/api/` prefix |
| **CORS Error** | Verify CORS headers: `curl -I http://localhost/api/users/login` |
| **Rate Limited** | Wait 1 minute or increase limit in nginx-proxy.conf |
| **SSL Error** | Run: `./deploy/setup-ssl.sh yourdomain.com` |
| **Cache Issue** | Clear cache: `docker exec nginx-proxy rm -rf /var/cache/nginx/*` |

## 📝 Configuration Files

```
nginx/nginx-proxy.conf          → Main NGINX configuration
nginx/Dockerfile.proxy          → NGINX Docker image
docker-compose.yml              → Only port 80 exposed
deploy/setup-ssl.sh             → SSL certificate setup
deploy/test-proxy.sh            → Test all routes
```

## 🎨 Rate Limits

```
Login:         5 requests/minute per IP
General API:   100 requests/minute per IP
Burst:         +20 requests allowed
```

## 💾 Caching

```
Market Data:   5 minutes cache
Static Files:  1 year cache
APIs:          No cache (dynamic data)
```

## 🔄 Common Tasks

```bash
# Deploy new version (zero downtime)
./deploy/deploy-service.sh user-service

# Scale service with load balancing
docker-compose up -d --scale portfolio-service=3

# View logs
docker-compose logs -f nginx-proxy

# Backup
./backup.sh

# Full restart
docker-compose down && docker-compose up -d

# Update SSL certificate
sudo certbot renew && docker-compose restart nginx-proxy
```

## 📞 Quick Status Check

```bash
# All-in-one status command
echo "NGINX: $(curl -s http://localhost/health | jq -r .status)"
echo "Frontend: $(curl -s -o /dev/null -w '%{http_code}' http://localhost/)"
echo "User: $(curl -s http://localhost/api/users/health | jq -r .status)"
echo "Portfolio: $(curl -s http://localhost/api/portfolio/health | jq -r .status)"
echo "Market: $(curl -s http://localhost/api/market/health | jq -r .status)"
echo "Dividend: $(curl -s http://localhost/api/dividends/health | jq -r .status)"
```

## 🎯 Migration Checklist

```bash
# Before
□ Backup: docker-compose down && tar -czf backup.tar.gz .
□ Test: ./test-proxy.sh

# Deploy
□ Update: git pull origin main
□ Start: docker-compose up -d
□ Verify: ./test-proxy.sh

# After
□ Update Security Group (remove ports 3000-3005)
□ Update DNS (if using domain)
□ Enable SSL: ./deploy/setup-ssl.sh yourdomain.com
□ Monitor logs for 24 hours
```

## 🎉 Success Indicators

✅ Only port 80 (and 443) in security group  
✅ All URLs use single domain  
✅ Test script shows all green checkmarks  
✅ Frontend loads at http://your-ip/  
✅ No port numbers in user-facing URLs  
✅ HTTPS works (if enabled)  
✅ Rate limiting blocks excessive requests  
✅ Logs show no 502/504 errors  

## 🆘 Emergency Commands

```bash
# Quick fix - restart everything
docker-compose restart

# Nuclear option - full reset
docker-compose down -v
./deploy/base-setup.sh
docker-compose up -d

# Check NGINX config is valid
docker exec stock-portfolio-nginx-proxy nginx -t

# Emergency log check
docker logs --tail 100 stock-portfolio-nginx-proxy | grep error
```

---

## 📋 Copy-Paste Commands

### Deploy from Scratch
```bash
git clone <repo> && cd stock-portfolio
cp .env.example .env && nano .env
chmod +x deploy/*.sh
./deploy/base-setup.sh
docker-compose up -d
./test-proxy.sh
```

### Update Single Service
```bash
cd stock-portfolio && git pull
./deploy/deploy-service.sh user-service
curl http://localhost/api/users/health
```

### Enable HTTPS
```bash
./deploy/setup-ssl.sh yourdomain.com
```

### Monitor Everything
```bash
watch -n 5 './test-proxy.sh'
```

---

**Remember**: Only **ONE** port (80) exposed to users! 🎯  
**Access**: http://your-domain/ for everything! 🚀