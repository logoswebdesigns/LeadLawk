#!/bin/bash
# Start LeadLoq Server - One Button Solution
# This script handles the complete server startup process

set -e  # Exit on error

echo "🚀 Starting LeadLoq Server..."

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Check if docker-compose is available
if ! command -v docker-compose >/dev/null 2>&1; then
    echo "❌ docker-compose not found. Please install Docker Compose."
    exit 1
fi

# Navigate to server directory
cd "$(dirname "$0")/server"

# Pull latest images (for production)
echo "📦 Pulling latest container images..."
docker-compose pull

# Build the API container
echo "🔨 Building API container..."
docker-compose build leadloq-api

# Start all services
echo "🐳 Starting containers..."
docker-compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 5

# Check if API is responding
for i in {1..10}; do
    if curl -s http://localhost:8000/health >/dev/null; then
        echo "✅ API is ready!"
        break
    fi
    if [ $i -eq 10 ]; then
        echo "❌ API failed to start. Check logs with: docker-compose logs"
        exit 1
    fi
    sleep 2
done

# Check if Selenium is responding  
for i in {1..10}; do
    if curl -s http://localhost:4444/status >/dev/null; then
        echo "✅ Browser automation is ready!"
        break
    fi
    if [ $i -eq 10 ]; then
        echo "⚠️  Browser automation may not be ready. Check logs with: docker-compose logs selenium-chrome"
    fi
    sleep 2
done

echo ""
echo "🎉 LeadLoq Server is running!"
echo "📱 API: http://localhost:8000"
echo "🔧 API Docs: http://localhost:8000/docs"
echo "🖥️  Browser Debug (VNC): http://localhost:7900 (password: secret)"
echo ""
echo "📊 To monitor:"
echo "   docker-compose logs -f"
echo ""
echo "🛑 To stop:"
echo "   docker-compose down"