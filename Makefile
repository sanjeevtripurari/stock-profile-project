.PHONY: help setup start stop restart logs clean deploy-service health backup

# Default target
help:
	@echo "Stock Portfolio Management System"
	@echo "================================="
	@echo ""
	@echo "Available commands:"
	@echo "  make setup          - Initial setup (run once)"
	@echo "  make start          - Start all services"
	@echo "  make stop           - Stop all services"
	@echo "  make restart        - Restart all services"
	@echo "  make logs           - View logs"
	@echo "  make health         - Check service health"
	@echo "  make clean          - Clean up containers and volumes"
	@echo "  make fix            - Fix Docker build issues"
	@echo ""
	@echo "Service deployment:"
	@echo "  make deploy-user    - Deploy user service"
	@echo "  make deploy-portfolio - Deploy portfolio service"
	@echo "  make deploy-market  - Deploy market data service"
	@echo "  make deploy-dividend - Deploy dividend service"
	@echo "  make deploy-frontend - Deploy frontend"
	@echo ""
	@echo "Maintenance:"
	@echo "  make backup         - Backup database"
	@echo "  make monitor        - Monitor system"
	@echo "  make test-proxy     - Test NGINX routing"
	@echo "  make test-mvp       - Test MVP mode functionality"
	@echo "  make test-backend   - Test complete backend API"
	@echo "  make debug          - Debug system issues"
	@echo "  make logs-all       - Show all service logs"
	@echo "  make clean-rebuild  - Clean rebuild everything"

# Initial setup
setup:
	@echo "🚀 Setting up Stock Portfolio System..."
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "⚠️  Created .env file from template. Please edit it with your values!"; \
		echo "   Required: ALPHA_VANTAGE_API_KEY, POSTGRES_PASSWORD, REDIS_PASSWORD, JWT_SECRET"; \
	fi
	@chmod +x deploy/*.sh scripts/*.sh
	@./deploy/base-setup.sh

# Start all services
start:
	@echo "🚀 Starting all services..."
	@docker-compose up -d

# Stop all services
stop:
	@echo "🛑 Stopping all services..."
	@docker-compose down

# Restart all services
restart:
	@echo "🔄 Restarting all services..."
	@docker-compose restart

# View logs
logs:
	@docker-compose logs -f

# Health check
health:
	@./deploy/health-check.sh

# Clean up
clean:
	@echo "🧹 Cleaning up containers and volumes..."
	@docker-compose down -v
	@docker system prune -f

# Deploy individual services
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

# Backup database
backup:
	@./scripts/backup.sh

# Monitor system
monitor:
	@./scripts/monitor.sh

# Test NGINX proxy routing
test-proxy:
	@./deploy/test-proxy.sh

# Development mode
dev:
	@echo "🔧 Starting in development mode..."
	@docker-compose -f docker-compose.yml -f docker-compose.dev.yml up

# Build all images
build:
	@echo "🔨 Building all Docker images..."
	@docker-compose build

# Pull latest images
pull:
	@echo "📥 Pulling latest images..."
	@docker-compose pull

# Show status
status:
	@echo "📊 Service Status:"
	@docker-compose ps

# Show resource usage
stats:
	@echo "📈 Resource Usage:"
	@docker stats --no-stream

# Quick test
test:
	@echo "🧪 Running quick tests..."
	@./deploy/health-check.sh
	@./deploy/test-proxy.sh

# Fix Docker build issues
fix:
	@echo "🔧 Fixing Docker build issues..."
	@./fix-docker-build.sh

# Update system
update:
	@echo "🔄 Updating system..."
	@git pull origin main
	@docker-compose pull
	@docker-compose up -d

# Show logs for specific service
logs-user:
	@docker logs -f stock-portfolio-user-service

logs-portfolio:
	@docker logs -f stock-portfolio-portfolio-service

logs-market:
	@docker logs -f stock-portfolio-market-data-service

logs-dividend:
	@docker logs -f stock-portfolio-dividend-service

logs-frontend:
	@docker logs -f stock-portfolio-frontend

logs-nginx:
	@docker logs -f stock-portfolio-nginx-proxy

logs-postgres:
	@docker logs -f stock-portfolio-postgres

logs-redis:
	@docker logs -f stock-portfolio-redis# Te
st MVP mode functionality
test-mvp:
	@echo "🧪 Testing MVP Mode functionality..."
	@./scripts/test-mvp-mode.sh# Test
 complete backend API
test-backend:
	@echo "🧪 Testing complete backend API..."
	@./test-backend-complete.sh# Debug sys
tem issues
debug:
	@echo "🔍 Running system debug..."
	@./debug-system.sh

# Show all service logs
logs-all:
	@echo "📋 Showing all service logs..."
	@docker-compose logs --tail=20

# Clean rebuild everything
clean-rebuild:
	@echo "🧹 Clean rebuild..."
	@docker-compose down -v
	@docker-compose build --no-cache
	@docker-compose up -d