# GeoServer Health Check Script
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

function Test-GeoServerEndpoint {
    param([string]$Url, [string]$Description)
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $response = Invoke-WebRequest -Uri $Url -Method GET -TimeoutSec 10 -UseBasicParsing
        $sw.Stop()
        $color = if ($response.StatusCode -eq 200) { "Green" } else { "Yellow" }
        Write-Host " $Description" -ForegroundColor $color
        Write-Host "  Status: $($response.StatusCode) | Response Time: $($sw.ElapsedMilliseconds)ms" -ForegroundColor Gray
        return $true
    }
    catch {
        Write-Host " $Description" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

Write-Host "1. Docker Container Status" -ForegroundColor Yellow
$containerStatus = docker ps --filter "name=geoserver" --format "{{.Status}}"
if ($containerStatus) {
    Write-Host " Container is running" -ForegroundColor Green
    Write-Host "  Status: $containerStatus" -ForegroundColor Gray
} else {
    Write-Host " Container is not running" -ForegroundColor Red
    exit 1
}

Write-Host "`n2. Web Interface Checks" -ForegroundColor Yellow
$webOk = Test-GeoServerEndpoint -Url "$GeoServerUrl/web/" -Description "Web Interface"
$wmsUrl = "$GeoServerUrl/wms?service=wms&version=1.1.0&request=GetCapabilities"
$wfsUrl = "$GeoServerUrl/wfs?service=wfs&version=1.1.0&request=GetCapabilities"
$wmsOk = Test-GeoServerEndpoint -Url $wmsUrl -Description "WMS Service"
$wfsOk = Test-GeoServerEndpoint -Url $wfsUrl -Description "WFS Service"

Write-Host "`n3. Resource Usage" -ForegroundColor Yellow
$stats = docker stats geoserver --no-stream --format '{{.CPUPerc}}|{{.MemUsage}}|{{.NetIO}}|{{.BlockIO}}'
$statsArray = $stats -split '\|'
Write-Host "  CPU Usage:     $($statsArray[0])" -ForegroundColor Gray
Write-Host "  Memory Usage:  $($statsArray[1])" -ForegroundColor Gray

Write-Host "`n========================================" -ForegroundColor Cyan
if ($webOk -and $wmsOk -and $wfsOk) {
    Write-Host " All checks passed!" -ForegroundColor Green
    Write-Host "`nGeoServer is running at: $GeoServerUrl" -ForegroundColor Cyan
    exit 0
} else {
    Write-Host " Some checks failed!" -ForegroundColor Red
    exit 1
}
