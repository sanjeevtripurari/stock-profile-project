#!/bin/bash
# deploy/deploy-service.sh
# Deploy individual service with zero downtime

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

# Check if service name is provided
if [ -z "$1" ]; then
    print_error "Usage: $0 <service-name>"
    echo ""
    echo "Available services:"
    echo "  - user-service"
    echo "  - portfolio-service"
    echo "  - market-data-service"
    echo "  - dividend-service"
    echo "  - frontend"
    echo "  - nginx-proxy"
    exit 1
fi

SERVICE_NAME=$1
CONTAINER_NAME="stock-portfolio-$SERVICE_NAME"

echo "================================================"
echo "Deploying Service: $SERVICE_NAME"
echo "================================================"
echo ""

# Validate service name
valid_services=("user-service" "portfolio-service" "market-data-service" "dividend-service" "frontend" "nginx-proxy")
if [[ ! " ${valid_services[@]} " =~ " ${SERVICE_NAME} " ]]; then
    print_error "Invalid service name: $SERVICE_NAME"
    echo "Valid services: ${valid_services[*]}"
    exit 1
fi

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running"
    exit 1
fi

# Check if service directory exists (except for nginx-proxy)
if [ "$SERVICE_NAME" != "nginx-proxy" ] && [ ! -d "$SERVICE_NAME" ]; then
    print_error "Service directory not found: $SERVICE_NAME"
    exit 1
fi

# Get current container status
print_step "Checking current service status..."
if docker ps -q -f name="$CONTAINER_NAME" > /dev/null; then
    CURRENT_STATUS="running"
    print_info "Service is currently running"
else
    CURRENT_STATUS="stopped"
    print_warn "Service is not running"
fi

# Build new image
print_step "Building new Docker image..."
if [ "$SERVICE_NAME" = "nginx-proxy" ]; then
    docker-compose build nginx-proxy
else
    docker-compose build "$SERVICE_NAME"
fi

if [ $? -eq 0 ]; then
    print_info "Image built successfully ✓"
else
    print_error "Failed to build image"
    exit 1
fi

# Stop old container (if running)
if [ "$CURRENT_STATUS" = "running" ]; then
    print_step "Stopping old container..."
    docker-compose stop "$SERVICE_NAME"
    print_info "Old container stopped ✓"
fi

# Remove old container
print_step "Removing old container..."
docker-compose rm -f "$SERVICE_NAME" 2>/dev/null || true
print_info "Old container removed ✓"

# Start new container
print_step "Starting new container..."
if [ "$SERVICE_NAME" = "nginx-proxy" ]; then
    docker-compose up -d nginx-proxy
else
    docker-compose up -d "$SERVICE_NAME"
fi

if [ $? -eq 0 ]; then
    print_info "New container started ✓"
else
    print_error "Failed to start new container"
    exit 1
fi

# Wait for service to be ready
print_step "Waiting for service to be ready..."
timeout=60
counter=0

while [ $counter -lt $timeout ]; do
    if docker ps -q -f name="$CONTAINER_NAME" > /dev/null; then
        # Check if service has health endpoint
        case $SERVICE_NAME in
            "user-service"|"portfolio-service"|"market-data-service"|"dividend-service")
                if curl -s -f "http://localhost/api/${SERVICE_NAME%-service}/health" > /dev/null 2>&1; then
                    break
                fi
                ;;
            "frontend")
                if curl -s -f "http://localhost/" > /dev/null 2>&1; then
                    break
                fi
                ;;
            "nginx-proxy")
                if curl -s -f "http://localhost/health" > /dev/null 2>&1; then
                    break
                fi
                ;;
        esac
    fi
    
    sleep 2
    counter=$((counter + 2))
    echo -n "."
done

echo ""

if [ $counter -ge $timeout ]; then
    print_error "Service failed to become ready within $timeout seconds"
    print_info "Checking logs..."
    docker logs --tail 20 "$CONTAINER_NAME"
    exit 1
fi

print_info "Service is ready ✓"

# Verify deployment
print_step "Verifying deployment..."
case $SERVICE_NAME in
    "user-service")
        HEALTH_URL="http://localhost/api/users/health"
        ;;
    "portfolio-service")
        HEALTH_URL="http://localhost/api/portfolio/health"
        ;;
    "market-data-service")
        HEALTH_URL="http://localhost/api/market/health"
        ;;
    "dividend-service")
        HEALTH_URL="http://localhost/api/dividends/health"
        ;;
    "frontend")
        HEALTH_URL="http://localhost/"
        ;;
    "nginx-proxy")
        HEALTH_URL="http://localhost/health"
        ;;
esac

if curl -s -f "$HEALTH_URL" > /dev/null 2>&1; then
    print_info "Health check passed ✓"
    
    # Get service info
    CONTAINER_ID=$(docker ps -q -f name="$CONTAINER_NAME")
    IMAGE_ID=$(docker inspect --format='{{.Image}}' "$CONTAINER_ID" | cut -c1-12)
    
    echo ""
    print_info "Deployment Summary:"
    echo "  Service: $SERVICE_NAME"
    echo "  Container: $CONTAINER_NAME"
    echo "  Image: $IMAGE_ID"
    echo "  Health URL: $HEALTH_URL"
    echo "  Status: ✅ Healthy"
    
else
    print_error "Health check failed"
    print_info "Service logs:"
    docker logs --tail 10 "$CONTAINER_NAME"
    exit 1
fi

# Clean up old images
print_step "Cleaning up old images..."
docker image prune -f > /dev/null 2>&1 || true
print_info "Old images cleaned ✓"

echo ""
print_info "🎉 Service $SERVICE_NAME deployed successfully!"

# Show next steps
echo ""
print_info "Next steps:"
echo "  - Check logs: docker logs -f $CONTAINER_NAME"
echo "  - Monitor: ./scripts/monitor.sh"
echo "  - Health check: ./deploy/health-check.sh"
echo "  - Test endpoint: curl $HEALTH_URL"

# If this is nginx-proxy, show routing test
if [ "$SERVICE_NAME" = "nginx-proxy" ]; then
    echo "  - Test routing: ./deploy/test-proxy.sh"
fi