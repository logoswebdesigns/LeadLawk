#!/bin/bash

# LeadLawk Resilient Deployment Script
# Based on production deployment best practices

set -e  # Exit on error

echo "🚀 LeadLawk Resilient Deployment Starting..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if service is healthy
check_service_health() {
    local service=$1
    local url=$2
    local max_attempts=30
    local attempt=0
    
    echo -n "Waiting for $service to be healthy..."
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -f -s "$url" > /dev/null 2>&1; then
            echo -e " ${GREEN}✓${NC}"
            return 0
        fi
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo -e " ${RED}✗${NC}"
    return 1
}

# Stop existing services
echo "📦 Stopping existing services..."
docker-compose -f docker-compose.resilient.yml down 2>/dev/null || true

# Clean up old containers and images
echo "🧹 Cleaning up old resources..."
docker system prune -f

# Build new images
echo "🔨 Building Docker images..."
docker-compose -f docker-compose.resilient.yml build --no-cache

# Start services
echo "🚀 Starting services..."
docker-compose -f docker-compose.resilient.yml up -d

# Wait for services to be healthy
echo ""
echo "🏥 Checking service health..."

# Check Redis
if check_service_health "Redis" "http://localhost:6379"; then
    echo -e "  Redis: ${GREEN}Healthy${NC}"
else
    echo -e "  Redis: ${RED}Failed${NC}"
    exit 1
fi

# Check Selenium
if check_service_health "Selenium" "http://localhost:4444/status"; then
    echo -e "  Selenium: ${GREEN}Healthy${NC}"
else
    echo -e "  Selenium: ${YELLOW}Warning - Selenium not ready${NC}"
fi

# Check API
if check_service_health "API" "http://localhost:8000/health"; then
    echo -e "  API: ${GREEN}Healthy${NC}"
else
    echo -e "  API: ${RED}Failed${NC}"
    exit 1
fi

# Check Flower (Celery monitoring)
if check_service_health "Flower" "http://localhost:5555"; then
    echo -e "  Flower: ${GREEN}Healthy${NC}"
else
    echo -e "  Flower: ${YELLOW}Warning - Flower not ready${NC}"
fi

echo ""
echo "✅ Deployment Complete!"
echo ""
echo "📊 Service URLs:"
echo "  - API: http://localhost:8000"
echo "  - API Docs: http://localhost:8000/docs"
echo "  - Flower (Celery): http://localhost:5555 (admin:leadloq123)"
echo "  - Selenium VNC: http://localhost:7900 (password: secret)"
echo "  - Prometheus: http://localhost:9090"
echo "  - Grafana: http://localhost:3000 (admin:leadloq123)"
echo ""
echo "📝 Useful commands:"
echo "  - View logs: docker-compose -f docker-compose.resilient.yml logs -f"
echo "  - Stop services: docker-compose -f docker-compose.resilient.yml down"
echo "  - View metrics: curl http://localhost:8000/metrics"
echo "  - Check health: curl http://localhost:8000/health"
echo ""
echo "🎯 Starting overnight job monitoring..."
echo ""

# Start monitoring loop
monitor_services() {
    while true; do
        # Get current metrics
        if curl -s http://localhost:8000/metrics > /dev/null 2>&1; then
            metrics=$(curl -s http://localhost:8000/metrics)
            leads_per_hour=$(echo "$metrics" | grep "leads_per_hour" | awk '{print $2}')
            success_rate=$(echo "$metrics" | grep "success_rate" | awk '{print $2}')
            active_jobs=$(echo "$metrics" | grep "active_jobs" | awk '{print $2}')
            
            # Display metrics
            echo -ne "\r📊 Metrics: Leads/Hour: ${GREEN}${leads_per_hour:-0}${NC} | Success Rate: ${GREEN}${success_rate:-0}%${NC} | Active Jobs: ${YELLOW}${active_jobs:-0}${NC}   "
        else
            echo -ne "\r⚠️  API not responding - checking health...                                    "
            
            # Check if services need restart
            if ! curl -f -s http://localhost:8000/health > /dev/null 2>&1; then
                echo ""
                echo -e "${RED}❌ API is unhealthy - restarting...${NC}"
                docker-compose -f docker-compose.resilient.yml restart leadloq-api
                sleep 10
            fi
        fi
        
        sleep 5
    done
}

# Ask if user wants to start monitoring
read -p "Start real-time monitoring? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Starting monitor (Press Ctrl+C to stop)..."
    monitor_services
fi