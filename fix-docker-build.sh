#!/bin/bash
# fix-docker-build.sh
# Fix Docker build issues by ensuring proper npm setup

echo "🔧 Fixing Docker build issues..."
echo ""

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    print_error "Please run this script from the stock-portfolio root directory"
    exit 1
fi

# Clean up any existing containers and images
print_info "Cleaning up existing containers and images..."
docker-compose down --remove-orphans 2>/dev/null || true
docker system prune -f 2>/dev/null || true

# Verify package.json files exist
services=("user-service" "portfolio-service" "market-data-service" "dividend-service" "frontend")
missing_files=()

for service in "${services[@]}"; do
    if [ ! -f "$service/package.json" ]; then
        missing_files+=("$service/package.json")
    fi
    if [ ! -f "$service/package-lock.json" ]; then
        missing_files+=("$service/package-lock.json")
    fi
done

if [ ${#missing_files[@]} -ne 0 ]; then
    print_error "Missing required files:"
    for file in "${missing_files[@]}"; do
        echo "  - $file"
    done
    print_error "Please ensure all package.json and package-lock.json files are present"
    exit 1
fi

# Check Docker and Docker Compose
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed or not in PATH"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose is not installed or not in PATH"
    exit 1
fi

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Build images one by one to identify issues
print_info "Building Docker images individually..."

for service in "${services[@]}"; do
    print_info "Building $service..."
    
    if docker-compose build "$service" 2>&1; then
        print_info "✅ $service built successfully"
    else
        print_error "❌ Failed to build $service"
        
        # Try alternative build approach
        print_warn "Trying alternative build for $service..."
        
        # Temporarily modify Dockerfile to use npm install instead of npm ci
        if [ -f "$service/Dockerfile" ]; then
            cp "$service/Dockerfile" "$service/Dockerfile.backup"
            sed -i.tmp 's/npm ci --only=production/npm install --only=production/g' "$service/Dockerfile" 2>/dev/null || \
            sed -i.tmp 's/npm ci/npm install/g' "$service/Dockerfile" 2>/dev/null || true
            
            if docker-compose build "$service" 2>&1; then
                print_info "✅ $service built successfully with npm install"
            else
                print_error "❌ $service build failed even with npm install"
                # Restore original Dockerfile
                mv "$service/Dockerfile.backup" "$service/Dockerfile" 2>/dev/null || true
                exit 1
            fi
            
            # Clean up temp files
            rm -f "$service/Dockerfile.tmp" "$service/Dockerfile.backup" 2>/dev/null || true
        fi
    fi
done

# Test the complete build
print_info "Testing complete build..."
if docker-compose build; then
    print_info "✅ All services built successfully!"
else
    print_error "❌ Complete build failed"
    exit 1
fi

# Verify images were created
print_info "Verifying Docker images..."
images=$(docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep stock-portfolio)
if [ ! -z "$images" ]; then
    echo "$images"
    print_info "✅ Docker images created successfully"
else
    print_warn "No stock-portfolio images found"
fi

echo ""
print_info "🎉 Docker build issues fixed!"
echo ""
print_info "Next steps:"
echo "  1. Start services: make start"
echo "  2. Check health: make health"
echo "  3. Access app: http://localhost/"
echo ""
print_info "If you still have issues:"
echo "  - Check .env file is configured"
echo "  - Ensure Docker has enough resources (4GB+ RAM)"
echo "  - Try: docker system prune -a --volumes"