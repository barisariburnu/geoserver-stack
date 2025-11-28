# GeoServer Health Check Script
# Description: Checks if GeoServer is running and responsive

param(
    [string]$GeoServerUrl = "http://localhost:8080/geoserver",
    [string]$AdminUser = "admin",
    [string]$AdminPassword = "",
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "GeoServer Health Check" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Function to measure response time
function Test-GeoServerEndpoint {
    param(
        [string]$Url,
        [string]$Description
    )
    
    try {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $response = Invoke-WebRequest -Uri $Url -Method GET -TimeoutSec 10 -UseBasicParsing
        $stopwatch.Stop()
        
        $statusColor = if ($response.StatusCode -eq 200) { "Green" } else { "Yellow" }
        Write-Host "✓ $Description" -ForegroundColor $statusColor
        Write-Host "  Status: $($response.StatusCode) | Response Time: $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor Gray
        
        return $true
    }
    catch {
        Write-Host "✗ $Description" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to test authenticated endpoint
function Test-GeoServerAuth {
    param(
        [string]$Url,
        [string]$User,
        [string]$Password
    )
    
    try {
        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${User}:${Password}"))
        $headers = @{
            Authorization = "Basic $base64AuthInfo"
        }
        
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $response = Invoke-RestMethod -Uri $Url -Method GET -Headers $headers -TimeoutSec 10
        $stopwatch.Stop()
        
        Write-Host "✓ REST API Authentication" -ForegroundColor Green
        Write-Host "  Response Time: $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor Gray
        
        if ($Verbose) {
            Write-Host "  Version Info:" -ForegroundColor Gray
            $response | ConvertTo-Json -Depth 3 | Write-Host -ForegroundColor DarkGray
        }
        
        return $true
    }
    catch {
        Write-Host "✗ REST API Authentication" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Check Docker container status
Write-Host "1. Docker Container Status" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────" -ForegroundColor DarkGray

try {
    $containerStatus = docker ps --filter "name=geoserver" --format "{{.Status}}"
    
    if ($containerStatus) {
        Write-Host "✓ Container is running" -ForegroundColor Green
        Write-Host "  Status: $containerStatus" -ForegroundColor Gray
    }
    else {
        Write-Host "✗ Container is not running" -ForegroundColor Red
        Write-Host "  Run: docker-compose up -d" -ForegroundColor Yellow
        exit 1
    }
}
catch {
    Write-Host "✗ Docker command failed" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Check web interface
Write-Host "2. Web Interface Checks" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────" -ForegroundColor DarkGray

$webOk = Test-GeoServerEndpoint -Url "$GeoServerUrl/web/" -Description "Web Interface"
$wmsOk = Test-GeoServerEndpoint -Url "$GeoServerUrl/wms?service=wms&version=1.1.0&request=GetCapabilities" -Description "WMS Service"
$wfsOk = Test-GeoServerEndpoint -Url "$GeoServerUrl/wfs?service=wfs&version=1.1.0&request=GetCapabilities" -Description "WFS Service"

Write-Host ""

# Check REST API (if credentials provided)
if ($AdminPassword) {
    Write-Host "3. REST API Checks" -ForegroundColor Yellow
    Write-Host "─────────────────────────────────────" -ForegroundColor DarkGray
    
    $restOk = Test-GeoServerAuth -Url "$GeoServerUrl/rest/about/version.json" -User $AdminUser -Password $AdminPassword
    
    Write-Host ""
}

# Check container resources
Write-Host "4. Resource Usage" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────" -ForegroundColor DarkGray

try {
    $stats = docker stats geoserver --no-stream --format '{{.CPUPerc}}|{{.MemUsage}}|{{.NetIO}}|{{.BlockIO}}'
    $statsArray = $stats -split '\|'
    
    Write-Host "  CPU Usage:     $($statsArray[0])" -ForegroundColor Gray
    Write-Host "  Memory Usage:  $($statsArray[1])" -ForegroundColor Gray
    Write-Host "  Network I/O:   $($statsArray[2])" -ForegroundColor Gray
    Write-Host "  Block I/O:     $($statsArray[3])" -ForegroundColor Gray
}
catch {
    Write-Host "✗ Failed to get container stats" -ForegroundColor Red
}

Write-Host ""

# Check data directory
Write-Host "5. Data Directory" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────" -ForegroundColor DarkGray

$dataDir = "D:\geoserver_data"
if (Test-Path $dataDir) {
    $dirSize = (Get-ChildItem -Path $dataDir -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    $dirSizeMB = [math]::Round($dirSize / 1MB, 2)
    
    Write-Host "✓ Data directory exists" -ForegroundColor Green
    Write-Host "  Location: $dataDir" -ForegroundColor Gray
    Write-Host "  Size: $dirSizeMB MB" -ForegroundColor Gray
}
else {
    Write-Host "✗ Data directory not found" -ForegroundColor Red
    Write-Host "  Expected: $dataDir" -ForegroundColor Red
}

Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Health Check Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$allOk = $webOk -and $wmsOk -and $wfsOk

if ($allOk) {
    Write-Host "✓ All checks passed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "GeoServer is running at: $GeoServerUrl" -ForegroundColor Cyan
    exit 0
}
else {
    Write-Host "✗ Some checks failed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Check the logs: docker-compose logs geoserver" -ForegroundColor Yellow
    exit 1
}
