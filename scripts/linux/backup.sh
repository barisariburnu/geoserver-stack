#!/bin/bash
# GeoServer Backup Script
# Description: Creates a timestamped backup of GeoServer data directory

set -e

SOURCE_DIR="${SOURCE_DIR:-/opt/geoserver/data_dir}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
COMPRESS="${COMPRESS:-true}"
STOP_CONTAINER="${STOP_CONTAINER:-false}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}GeoServer Backup Utility${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Generate timestamp
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_NAME="geoserver_backup_$TIMESTAMP"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

echo -e "${GRAY}Source:      $SOURCE_DIR${NC}"
echo -e "${GRAY}Destination: $BACKUP_PATH${NC}"
echo -e "${GRAY}Compression: $COMPRESS${NC}"
echo ""

# Stop container if requested
if [ "$STOP_CONTAINER" = "true" ]; then
    echo -e "${YELLOW}Stopping GeoServer container...${NC}"
    if docker-compose stop geoserver 2>/dev/null; then
        echo -e "${GREEN}✓ Container stopped${NC}"
        sleep 5
    else
        echo -e "${RED}✗ Failed to stop container${NC}"
        exit 1
    fi
    echo ""
fi

# Perform backup
echo -e "${YELLOW}Starting backup...${NC}"
START_TIME=$(date +%s)

# Export data from container
echo -e "${GRAY}Exporting data from container...${NC}"

if [ "$COMPRESS" = "true" ]; then
    # Create compressed archive directly from container
    ARCHIVE_PATH="$BACKUP_PATH.tar.gz"
    
    if docker exec geoserver tar -czf "/tmp/backup.tar.gz" -C /opt/geoserver data_dir 2>/dev/null; then
        docker cp geoserver:/tmp/backup.tar.gz "$ARCHIVE_PATH"
        docker exec geoserver rm /tmp/backup.tar.gz
        
        ARCHIVE_SIZE=$(du -h "$ARCHIVE_PATH" | cut -f1)
        
        echo -e "${GREEN}✓ Backup completed: $ARCHIVE_PATH${NC}"
        echo -e "${GRAY}  Size: $ARCHIVE_SIZE${NC}"
    else
        echo -e "${RED}✗ Backup failed${NC}"
        
        # Restart container if it was stopped
        if [ "$STOP_CONTAINER" = "true" ]; then
            echo -e "${YELLOW}Restarting GeoServer container...${NC}"
            docker-compose start geoserver
        fi
        
        exit 1
    fi
else
    # Copy directory without compression
    mkdir -p "$BACKUP_PATH"
    
    if docker cp geoserver:/opt/geoserver/data_dir/. "$BACKUP_PATH/" 2>/dev/null; then
        BACKUP_SIZE=$(du -sh "$BACKUP_PATH" | cut -f1)
        
        echo -e "${GREEN}✓ Backup completed: $BACKUP_PATH${NC}"
        echo -e "${GRAY}  Size: $BACKUP_SIZE${NC}"
    else
        echo -e "${RED}✗ Backup failed${NC}"
        
        # Restart container if it was stopped
        if [ "$STOP_CONTAINER" = "true" ]; then
            echo -e "${YELLOW}Restarting GeoServer container...${NC}"
            docker-compose start geoserver
        fi
        
        exit 1
    fi
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo -e "${GRAY}  Duration: ${DURATION}s${NC}"
echo ""

# Restart container if it was stopped
if [ "$STOP_CONTAINER" = "true" ]; then
    echo -e "${YELLOW}Restarting GeoServer container...${NC}"
    if docker-compose start geoserver 2>/dev/null; then
        echo -e "${GREEN}✓ Container restarted${NC}"
    else
        echo -e "${RED}✗ Failed to restart container${NC}"
    fi
    echo ""
fi

# Clean up old backups
echo -e "${YELLOW}Cleaning up old backups (retention: $RETENTION_DAYS days)...${NC}"

CUTOFF_DATE=$(date -d "$RETENTION_DAYS days ago" +%Y-%m-%d 2>/dev/null || date -v-${RETENTION_DAYS}d +%Y-%m-%d)
REMOVED_COUNT=0

find "$BACKUP_DIR" -maxdepth 1 -name "geoserver_backup_*" -type f -o -name "geoserver_backup_*" -type d | while read -r backup; do
    BACKUP_DATE=$(basename "$backup" | grep -oP '\d{4}-\d{2}-\d{2}')
    
    if [ "$BACKUP_DATE" \< "$CUTOFF_DATE" ]; then
        if rm -rf "$backup" 2>/dev/null; then
            echo -e "${GRAY}  Removed: $(basename "$backup")${NC}"
            REMOVED_COUNT=$((REMOVED_COUNT + 1))
        else
            echo -e "${RED}  Failed to remove: $(basename "$backup")${NC}"
        fi
    fi
done

if [ $REMOVED_COUNT -eq 0 ]; then
    echo -e "${GRAY}  No old backups to remove${NC}"
else
    echo -e "${GREEN}✓ Removed $REMOVED_COUNT old backup(s)${NC}"
fi

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${GREEN}Backup completed successfully!${NC}"
echo -e "${CYAN}========================================${NC}"
