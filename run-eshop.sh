#!/bin/bash
# eShop DevOps - Complete Stack Runner
# This script runs the infrastructure and then the .NET Aspire Dashboard

echo " Starting eShop DevOps Stack..."

# Step 1: Start infrastructure services
echo " Starting infrastructure services (PostgreSQL, Redis, RabbitMQ)..."
docker compose -f docker-compose.yml up -d

# Wait for services to be healthy
echo " Waiting for services to be ready..."
sleep 20

# Check service health
echo " Checking service health..."
docker compose -f docker-compose.yml ps

# Step 2: Start .NET Aspire Dashboard
echo " Starting .NET Aspire Dashboard..."
echo "Dashboard will be available at: http://localhost:18848"
echo ""
echo " Available Services:"
echo "  - PostgreSQL: localhost:5432 (eshopuser/eshoppassword)"
echo "  - Redis: localhost:6379"
echo "  - RabbitMQ: localhost:5672"
echo "  - RabbitMQ Management: http://localhost:15672 (eshopuser/eshoppassword)"
echo "  - Aspire Dashboard: http://localhost:18848"
echo ""
echo "Press Ctrl+C to stop..."
echo ""

# Run the Aspire Dashboard
dotnet run --project src/eShop.AppHost/eShop.AppHost.csproj --launch-profile http
