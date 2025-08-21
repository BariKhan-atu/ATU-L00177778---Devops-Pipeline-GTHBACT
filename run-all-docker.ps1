# eShop Full Docker Startup Script
# This script runs everything using Docker (no .NET SDK required)

Write-Host "eShop Full Docker Startup" -ForegroundColor Green
Write-Host "=============================" -ForegroundColor Green

# Check if Docker is running
Write-Host "Checking Docker status..." -ForegroundColor Yellow
try {
    docker version | Out-Null
    Write-Host "Docker is running" -ForegroundColor Green
} catch {
    Write-Host "Docker is not running. Please start Docker Desktop first." -ForegroundColor Red
    exit 1
}

# Stop any existing containers
Write-Host "Stopping any existing containers..." -ForegroundColor Yellow
docker-compose -f docker-compose.working.yml down 2>$null

# Start all services
Write-Host "Starting all services (this will take several minutes for the first build)..." -ForegroundColor Yellow
Write-Host "Building and starting: PostgreSQL, Redis, RabbitMQ, and all .NET APIs..." -ForegroundColor Cyan

docker-compose -f docker-compose.working.yml up -d --build

# Wait for services to be ready
Write-Host "Waiting for services to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Check if services are running
Write-Host "Checking service status..." -ForegroundColor Yellow
docker-compose -f docker-compose.working.yml ps

Write-Host ""
Write-Host "All services are starting up!" -ForegroundColor Green
Write-Host ""
Write-Host "Your application will be available at:" -ForegroundColor Cyan
Write-Host "  Main WebApp: http://localhost:5000" -ForegroundColor Green
Write-Host "  Identity API: http://localhost:5001" -ForegroundColor White
Write-Host "  Basket API: http://localhost:5002" -ForegroundColor White
Write-Host "  Catalog API: http://localhost:5003" -ForegroundColor White
Write-Host "  Ordering API: http://localhost:5004" -ForegroundColor White
Write-Host ""
Write-Host "Infrastructure services:" -ForegroundColor Cyan
Write-Host "  PostgreSQL: localhost:5432" -ForegroundColor White
Write-Host "  Redis: localhost:6379" -ForegroundColor White
Write-Host "  RabbitMQ: localhost:5672" -ForegroundColor White
Write-Host "  RabbitMQ Management: http://localhost:15672 (eshopuser/eshoppassword)" -ForegroundColor White
Write-Host ""
Write-Host "To monitor services:" -ForegroundColor Yellow
Write-Host "  View status: docker-compose -f docker-compose.working.yml ps" -ForegroundColor White
Write-Host "  View logs: docker-compose -f docker-compose.working.yml logs -f" -ForegroundColor White
Write-Host "  Stop all: docker-compose -f docker-compose.working.yml down" -ForegroundColor White
Write-Host ""
Write-Host "Services are building and starting. This may take 5-10 minutes on first run." -ForegroundColor Yellow
Write-Host "Check http://localhost:5000 in your browser once everything is ready!" -ForegroundColor Green
Write-Host ""
Write-Host "Press any key to view real-time logs..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Show real-time logs
Write-Host "Showing real-time logs (press Ctrl+C to stop logs, services will continue running)..." -ForegroundColor Cyan
docker-compose -f docker-compose.working.yml logs -f
