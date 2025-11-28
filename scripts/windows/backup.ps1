# GeoServer Backup Script
# Description: Creates a timestamped backup of GeoServer data directory

param(
    [string]$SourceDir = "D:\geoserver_data",
    [string]$BackupDir = "D:\geoserver_backups",
    [int]$RetentionDays = 30,
    [switch]$Compress = $true,
    [switch]$StopContainer = $false
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "GeoServer Backup Utility" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Validate source directory
if (-not (Test-Path $SourceDir)) {
    Write-Host "✗ Source directory not found: $SourceDir" -ForegroundColor Red
    exit 1
}

# Create backup directory if it doesn't exist
if (-not (Test-Path $BackupDir)) {
    Write-Host "Creating backup directory: $BackupDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
}

# Generate timestamp
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$backupName = "geoserver_backup_$timestamp"
$backupPath = Join-Path $BackupDir $backupName

Write-Host "Source:      $SourceDir" -ForegroundColor Gray
Write-Host "Destination: $backupPath" -ForegroundColor Gray
Write-Host "Compression: $($Compress.IsPresent)" -ForegroundColor Gray
Write-Host ""

# Stop container if requested
if ($StopContainer) {
    Write-Host "Stopping GeoServer container..." -ForegroundColor Yellow
    try {
        docker-compose -f "d:\Workspace\geoserver\docker-compose.yml" stop geoserver
        Write-Host "✓ Container stopped" -ForegroundColor Green
        Start-Sleep -Seconds 5
    }
    catch {
        Write-Host "✗ Failed to stop container: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
    Write-Host ""
}

# Perform backup
Write-Host "Starting backup..." -ForegroundColor Yellow
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

try {
    if ($Compress) {
        # Create compressed archive
        $archivePath = "$backupPath.zip"
        Write-Host "Creating compressed archive..." -ForegroundColor Gray
        
        Compress-Archive -Path $SourceDir\* -DestinationPath $archivePath -CompressionLevel Optimal
        
        $archiveSize = (Get-Item $archivePath).Length
        $archiveSizeMB = [math]::Round($archiveSize / 1MB, 2)
        
        Write-Host "✓ Backup completed: $archivePath" -ForegroundColor Green
        Write-Host "  Size: $archiveSizeMB MB" -ForegroundColor Gray
    }
    else {
        # Copy directory
        Write-Host "Copying directory..." -ForegroundColor Gray
        Copy-Item -Path $SourceDir -Destination $backupPath -Recurse -Force
        
        $backupSize = (Get-ChildItem -Path $backupPath -Recurse | Measure-Object -Property Length -Sum).Sum
        $backupSizeMB = [math]::Round($backupSize / 1MB, 2)
        
        Write-Host "✓ Backup completed: $backupPath" -ForegroundColor Green
        Write-Host "  Size: $backupSizeMB MB" -ForegroundColor Gray
    }
}
catch {
    Write-Host "✗ Backup failed: $($_.Exception.Message)" -ForegroundColor Red
    
    # Restart container if it was stopped
    if ($StopContainer) {
        Write-Host "Restarting GeoServer container..." -ForegroundColor Yellow
        docker-compose -f "d:\Workspace\geoserver\docker-compose.yml" start geoserver
    }
    
    exit 1
}

$stopwatch.Stop()
Write-Host "  Duration: $($stopwatch.Elapsed.ToString('mm\:ss'))" -ForegroundColor Gray
Write-Host ""

# Restart container if it was stopped
if ($StopContainer) {
    Write-Host "Restarting GeoServer container..." -ForegroundColor Yellow
    try {
        docker-compose -f "d:\Workspace\geoserver\docker-compose.yml" start geoserver
        Write-Host "✓ Container restarted" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Failed to restart container: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

# Clean up old backups
Write-Host "Cleaning up old backups (retention: $RetentionDays days)..." -ForegroundColor Yellow

$cutoffDate = (Get-Date).AddDays(-$RetentionDays)
$oldBackups = Get-ChildItem -Path $BackupDir -Filter "geoserver_backup_*" | Where-Object { $_.LastWriteTime -lt $cutoffDate }

if ($oldBackups) {
    $removedCount = 0
    foreach ($backup in $oldBackups) {
        try {
            Remove-Item -Path $backup.FullName -Recurse -Force
            Write-Host "  Removed: $($backup.Name)" -ForegroundColor DarkGray
            $removedCount++
        }
        catch {
            Write-Host "  Failed to remove: $($backup.Name)" -ForegroundColor Red
        }
    }
    Write-Host "✓ Removed $removedCount old backup(s)" -ForegroundColor Green
}
else {
    Write-Host "  No old backups to remove" -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Backup completed successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
