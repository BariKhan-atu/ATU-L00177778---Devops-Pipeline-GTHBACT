# eShop Deployment Script
# This script deploys the eShop application to various environments

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("local", "dev", "staging", "production")]
    [string]$Environment = "local",
    
    [Parameter(Mandatory=$false)]
    [string]$Registry = "eshopacr.azurecr.io",
    
    [Parameter(Mandatory=$false)]
    [string]$Tag = "latest",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipTests,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipBuild
)

Write-Host "Starting eShop deployment to $Environment environment..." -ForegroundColor Green

# Set error action preference
$ErrorActionPreference = "Stop"

# Function to check if command exists
function Test-Command($CommandName) {
    try {
        Get-Command $CommandName -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

# Function to run command and check exit code
function Invoke-CommandWithCheck($Command, $Arguments) {
    Write-Host "Running: $Command $Arguments" -ForegroundColor Yellow
    $process = Start-Process -FilePath $Command -ArgumentList $Arguments -NoNewWindow -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "Command failed with exit code: $($process.ExitCode)"
    }
}

# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Blue

if (-not (Test-Command "dotnet")) {
    throw ".NET SDK is not installed or not in PATH"
}

if (-not (Test-Command "docker")) {
    throw "Docker is not installed or not in PATH"
}

if ($Environment -ne "local" -and -not (Test-Command "kubectl")) {
    throw "kubectl is not installed or not in PATH"
}

# Build and test (if not skipped)
if (-not $SkipBuild) {
    Write-Host "Building solution..." -ForegroundColor Blue
    
    # Restore packages
    Invoke-CommandWithCheck "dotnet" "restore"
    
    # Build solution
    Invoke-CommandWithCheck "dotnet" "build --configuration Release --no-restore"
    
    if (-not $SkipTests) {
        Write-Host "Running tests..." -ForegroundColor Blue
        Invoke-CommandWithCheck "dotnet" "test --configuration Release --no-build --verbosity normal"
    }
    
    # Publish applications
    Write-Host "Publishing applications..." -ForegroundColor Blue
    Invoke-CommandWithCheck "dotnet" "publish src/Identity.API/Identity.API.csproj --configuration Release --output src/Identity.API/bin/Release/net9.0/publish"
    Invoke-CommandWithCheck "dotnet" "publish src/Basket.API/Basket.API.csproj --configuration Release --output src/Basket.API/bin/Release/net9.0/publish"
    Invoke-CommandWithCheck "dotnet" "publish src/Catalog.API/Catalog.API.csproj --configuration Release --output src/Catalog.API/bin/Release/net9.0/publish"
    Invoke-CommandWithCheck "dotnet" "publish src/Ordering.API/Ordering.API.csproj --configuration Release --output src/Ordering.API/bin/Release/net9.0/publish"
    Invoke-CommandWithCheck "dotnet" "publish src/WebApp/WebApp.csproj --configuration Release --output src/WebApp/bin/Release/net9.0/publish"
}

# Build Docker images
Write-Host "Building Docker images..." -ForegroundColor Blue

$services = @("Identity.API", "Basket.API", "Catalog.API", "Ordering.API", "WebApp")

foreach ($service in $services) {
    Write-Host "Building $service..." -ForegroundColor Yellow
    $imageName = "$Registry/eshop/$($service.ToLower())"
    
    Invoke-CommandWithCheck "docker" "build -t $imageName`:$Tag -t $imageName`:latest src/$service"
}

# Deploy based on environment
switch ($Environment) {
    "local" {
        Write-Host "Deploying to local Docker Compose environment..." -ForegroundColor Blue
        
        # Stop existing containers
        Invoke-CommandWithCheck "docker-compose" "down"
        
        # Start services
        Invoke-CommandWithCheck "docker-compose" "up -d"
        
        Write-Host "Local deployment completed!" -ForegroundColor Green
        Write-Host "Services available at:" -ForegroundColor Yellow
        Write-Host "  WebApp: http://localhost:5000" -ForegroundColor White
        Write-Host "  Identity API: http://localhost:5001" -ForegroundColor White
        Write-Host "  Basket API: http://localhost:5002" -ForegroundColor White
        Write-Host "  Catalog API: http://localhost:5003" -ForegroundColor White
        Write-Host "  Ordering API: http://localhost:5004" -ForegroundColor White
        Write-Host "  RabbitMQ Management: http://localhost:15672" -ForegroundColor White
    }
    
    "dev" {
        Write-Host "Deploying to development Kubernetes cluster..." -ForegroundColor Blue
        
        # Create namespace
        Invoke-CommandWithCheck "kubectl" "apply -f k8s/namespace.yaml"
        
        # Apply secrets and configs
        Invoke-CommandWithCheck "kubectl" "apply -f k8s/postgres-secret.yaml"
        
        # Apply infrastructure
        Invoke-CommandWithCheck "kubectl" "apply -f k8s/postgres-pvc.yaml"
        Invoke-CommandWithCheck "kubectl" "apply -f k8s/postgres-deployment.yaml"
        Invoke-CommandWithCheck "kubectl" "apply -f k8s/redis-deployment.yaml"
        Invoke-CommandWithCheck "kubectl" "apply -f k8s/rabbitmq-deployment.yaml"
        
        # Wait for infrastructure to be ready
        Write-Host "Waiting for infrastructure to be ready..." -ForegroundColor Yellow
        Start-Sleep -Seconds 30
        
        # Apply application services
        Invoke-CommandWithCheck "kubectl" "apply -f k8s/identity-api-deployment.yaml"
        Invoke-CommandWithCheck "kubectl" "apply -f k8s/webapp-deployment.yaml"
        
        Write-Host "Development deployment completed!" -ForegroundColor Green
    }
    
    "staging" {
        Write-Host "Deploying to staging environment..." -ForegroundColor Blue
        
        # Update images with staging tag
        $stagingTag = "staging-$Tag"
        
        foreach ($service in $services) {
            $imageName = "$Registry/eshop/$($service.ToLower())"
            Invoke-CommandWithCheck "docker" "tag $imageName`:latest $imageName`:$stagingTag"
            Invoke-CommandWithCheck "docker" "push $imageName`:$stagingTag"
        }
        
        # Apply Kubernetes manifests with staging configuration
        Invoke-CommandWithCheck "kubectl" "apply -f k8s/ --namespace=eshop-staging"
        
        Write-Host "Staging deployment completed!" -ForegroundColor Green
    }
    
    "production" {
        Write-Host "Deploying to production environment..." -ForegroundColor Blue
        
        # Push images to registry
        foreach ($service in $services) {
            $imageName = "$Registry/eshop/$($service.ToLower())"
            Invoke-CommandWithCheck "docker" "push $imageName`:latest"
        }
        
        # Apply production Kubernetes manifests
        Invoke-CommandWithCheck "kubectl" "apply -f k8s/ --namespace=eshop-production"
        
        # Run health checks
        Write-Host "Running health checks..." -ForegroundColor Yellow
        Start-Sleep -Seconds 60
        
        # Verify deployment
        $pods = kubectl get pods --namespace=eshop-production -o json | ConvertFrom-Json
        $readyPods = ($pods.items | Where-Object { $_.status.phase -eq "Running" }).Count
        $totalPods = $pods.items.Count
        
        if ($readyPods -eq $totalPods) {
            Write-Host "Production deployment completed successfully!" -ForegroundColor Green
            Write-Host "All $totalPods pods are running" -ForegroundColor Green
        } else {
            throw "Deployment failed: $readyPods/$totalPods pods are running"
        }
    }
}

Write-Host "Deployment completed successfully!" -ForegroundColor Green

