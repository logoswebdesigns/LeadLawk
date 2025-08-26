#!/bin/bash
# Stop LeadLoq Server

set -e  # Exit on error

echo "🛑 Stopping LeadLoq Server..."

# Navigate to server directory
cd "$(dirname "$0")/server"

# Stop all services
docker-compose down

echo "✅ LeadLoq Server stopped."