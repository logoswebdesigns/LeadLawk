#!/bin/bash

# Script to start LeadLawk with configurable parallel execution

echo "🚀 LeadLawk Parallel Execution Launcher"
echo "======================================="

# Default number of parallel nodes
NODES=${1:-10}

echo "📊 Starting with $NODES parallel Chrome nodes..."

# Stop any existing containers
echo "🛑 Stopping existing containers..."
docker-compose down

# Start with scaled configuration
echo "🔧 Starting Selenium Grid with $NODES nodes..."
docker-compose -f docker-compose.scaled.yml up -d --scale selenium-node=$NODES

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 10

# Check Grid status
echo "✅ Checking Selenium Grid status..."
curl -s http://localhost:4444/status | python3 -c "
import json, sys
data = json.load(sys.stdin)
nodes = data['value']['nodes']
print(f'✅ Grid ready with {len(nodes)} nodes')
for node in nodes:
    slots = node['slots']
    print(f'   Node: {len(slots)} slot(s) available')
"

echo ""
echo "🎉 LeadLawk is ready for parallel execution!"
echo "   - API: http://localhost:8000"
echo "   - Selenium Grid: http://localhost:4444"
echo "   - Max parallel sessions: $NODES"
echo ""
echo "📝 To scale up/down:"
echo "   docker-compose -f docker-compose.scaled.yml up -d --scale selenium-node=20"