# GeoServer Performance Test Script
# Description: Performs load testing on GeoServer endpoints

param(
    [string]$GeoServerUrl = "http://localhost:8080/geoserver",
    [int]$Requests = 100,
    [int]$Concurrent = 10,
    [string]$TestType = "wms" # wms, wfs, rest
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "GeoServer Performance Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  URL:              $GeoServerUrl" -ForegroundColor Gray
Write-Host "  Test Type:        $TestType" -ForegroundColor Gray
Write-Host "  Total Requests:   $Requests" -ForegroundColor Gray
Write-Host "  Concurrent:       $Concurrent" -ForegroundColor Gray
Write-Host ""

# Define test endpoints
$endpoints = @{
    wms  = "$GeoServerUrl/wms?service=WMS&version=1.1.0&request=GetCapabilities"
    wfs  = "$GeoServerUrl/wfs?service=WFS&version=1.1.0&request=GetCapabilities"
    rest = "$GeoServerUrl/rest/about/version.json"
}

$testUrl = $endpoints[$TestType]

if (-not $testUrl) {
    Write-Host "✗ Invalid test type. Use: wms, wfs, or rest" -ForegroundColor Red
    exit 1
}

Write-Host "Testing endpoint: $testUrl" -ForegroundColor Cyan
Write-Host ""

# Performance metrics
$responseTimes = @()
$successCount = 0
$failureCount = 0

Write-Host "Running tests..." -ForegroundColor Yellow
$overallStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# Run requests in batches
$batchSize = [Math]::Min($Concurrent, $Requests)
$batches = [Math]::Ceiling($Requests / $batchSize)

for ($batch = 0; $batch -lt $batches; $batch++) {
    $remainingRequests = $Requests - ($batch * $batchSize)
    $currentBatchSize = [Math]::Min($batchSize, $remainingRequests)
    
    $jobs = @()
    
    # Start concurrent requests
    for ($i = 0; $i -lt $currentBatchSize; $i++) {
        $jobs += Start-Job -ScriptBlock {
            param($url)
            
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            try {
                $response = Invoke-WebRequest -Uri $url -Method GET -TimeoutSec 30 -UseBasicParsing
                $sw.Stop()
                
                return @{
                    Success    = $true
                    Duration   = $sw.ElapsedMilliseconds
                    StatusCode = $response.StatusCode
                }
            }
            catch {
                $sw.Stop()
                return @{
                    Success  = $false
                    Duration = $sw.ElapsedMilliseconds
                    Error    = $_.Exception.Message
                }
            }
        } -ArgumentList $testUrl
    }
    
    # Wait for jobs to complete
    $results = $jobs | Wait-Job | Receive-Job
    $jobs | Remove-Job
    
    # Process results
    foreach ($result in $results) {
        if ($result.Success) {
            $successCount++
            $responseTimes += $result.Duration
        }
        else {
            $failureCount++
        }
    }
    
    # Progress indicator
    $completed = ($batch + 1) * $batchSize
    $percentComplete = [Math]::Min(100, [Math]::Round(($completed / $Requests) * 100))
    Write-Progress -Activity "Performance Testing" -Status "$percentComplete% Complete" -PercentComplete $percentComplete
}

$overallStopwatch.Stop()
Write-Progress -Activity "Performance Testing" -Completed

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Results" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Calculate statistics
if ($responseTimes.Count -gt 0) {
    $avgResponseTime = ($responseTimes | Measure-Object -Average).Average
    $minResponseTime = ($responseTimes | Measure-Object -Minimum).Minimum
    $maxResponseTime = ($responseTimes | Measure-Object -Maximum).Maximum
    $medianResponseTime = ($responseTimes | Sort-Object)[[Math]::Floor($responseTimes.Count / 2)]
    
    # Calculate percentiles
    $sorted = $responseTimes | Sort-Object
    $p95Index = [Math]::Floor($sorted.Count * 0.95)
    $p99Index = [Math]::Floor($sorted.Count * 0.99)
    $p95ResponseTime = $sorted[$p95Index]
    $p99ResponseTime = $sorted[$p99Index]
    
    Write-Host "Request Statistics:" -ForegroundColor Yellow
    Write-Host "  Total Requests:    $Requests" -ForegroundColor Gray
    Write-Host "  Successful:        $successCount ($([Math]::Round(($successCount/$Requests)*100, 2))%)" -ForegroundColor Green
    Write-Host "  Failed:            $failureCount ($([Math]::Round(($failureCount/$Requests)*100, 2))%)" -ForegroundColor $(if ($failureCount -eq 0) { "Gray" } else { "Red" })
    Write-Host ""
    
    Write-Host "Response Times (ms):" -ForegroundColor Yellow
    Write-Host "  Average:           $([Math]::Round($avgResponseTime, 2))" -ForegroundColor Gray
    Write-Host "  Median:            $medianResponseTime" -ForegroundColor Gray
    Write-Host "  Min:               $minResponseTime" -ForegroundColor Gray
    Write-Host "  Max:               $maxResponseTime" -ForegroundColor Gray
    Write-Host "  95th Percentile:   $p95ResponseTime" -ForegroundColor Gray
    Write-Host "  99th Percentile:   $p99ResponseTime" -ForegroundColor Gray
    Write-Host ""
    
    $totalDuration = $overallStopwatch.Elapsed.TotalSeconds
    $requestsPerSecond = [Math]::Round($Requests / $totalDuration, 2)
    
    Write-Host "Performance:" -ForegroundColor Yellow
    Write-Host "  Total Duration:    $([Math]::Round($totalDuration, 2))s" -ForegroundColor Gray
    Write-Host "  Requests/Second:   $requestsPerSecond" -ForegroundColor Gray
    Write-Host ""
    
    # Performance assessment
    if ($avgResponseTime -lt 100) {
        Write-Host "✓ Excellent performance!" -ForegroundColor Green
    }
    elseif ($avgResponseTime -lt 500) {
        Write-Host "✓ Good performance" -ForegroundColor Yellow
    }
    else {
        Write-Host "⚠ Performance may need optimization" -ForegroundColor Red
    }
}
else {
    Write-Host "✗ No successful requests completed" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
