#!/bin/bash
# generate-lockfiles.sh
# Generate package-lock.json files for all services

echo "Generating package-lock.json files..."

services=("user-service" "portfolio-service" "market-data-service" "dividend-service" "frontend")

for service in "${services[@]}"; do
    if [ -d "$service" ] && [ -f "$service/package.json" ]; then
        echo "Generating lockfile for $service..."
        cd "$service"
        npm install --package-lock-only
        cd ..
        echo "✓ $service/package-lock.json created"
    else
        echo "✗ $service directory or package.json not found"
    fi
done

echo ""
echo "✅ All package-lock.json files generated!"
echo ""
echo "Now you can use 'npm ci' for faster, reproducible builds."
echo "To update Dockerfiles to use 'npm ci', run:"
echo "  sed -i 's/npm install --only=production/npm ci --only=production/g' */Dockerfile"