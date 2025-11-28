#!/bin/bash
# GeoServer Health Check Script
# Description: Checks if GeoServer is running and responsive

set -e

GEOSERVER_URL="${GEOSERVER_URL:-http://localhost:8080/geoserver}"
ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
VERBOSE="${VERBOSE:-false}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}GeoServer Health Check${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Function to test endpoint
test_endpoint() {
    local url="$1"
    local description="$2"
    
    start_time=$(date +%s%3N)
    
    if response=$(curl -s -w "\n%{http_code}" -o /tmp/geoserver_response.tmp "$url" 2>/dev/null); then
        http_code=$(echo "$response" | tail -n1)
        end_time=$(date +%s%3N)
        response_time=$((end_time - start_time))
        
        if [ "$http_code" -eq 200 ]; then
            echo -e "${GREEN}✓ $description${NC}"
            echo -e "${GRAY}  Status: $http_code | Response Time: ${response_time}ms${NC}"
            return 0
        else
            echo -e "${YELLOW}✓ $description${NC}"
            echo -e "${GRAY}  Status: $http_code | Response Time: ${response_time}ms${NC}"
            return 0
        fi
    else
        echo -e "${RED}✗ $description${NC}"
        echo -e "${RED}  Error: Connection failed${NC}"
        return 1
    fi
}

# Function to test authenticated endpoint
test_auth_endpoint() {
    local url="$1"
    local user="$2"
    local password="$3"
    
    start_time=$(date +%s%3N)
    
    if response=$(curl -s -w "\n%{http_code}" -u "$user:$password" -o /tmp/geoserver_auth_response.tmp "$url" 2>/dev/null); then
        http_code=$(echo "$response" | tail -n1)
        end_time=$(date +%s%3N)
        response_time=$((end_time - start_time))
        
        if [ "$http_code" -eq 200 ]; then
            echo -e "${GREEN}✓ REST API Authentication${NC}"
            echo -e "${GRAY}  Response Time: ${response_time}ms${NC}"
            
            if [ "$VERBOSE" = "true" ]; then
                echo -e "${GRAY}  Version Info:${NC}"
                cat /tmp/geoserver_auth_response.tmp | jq '.' 2>/dev/null || cat /tmp/geoserver_auth_response.tmp
            fi
            return 0
        else
            echo -e "${RED}✗ REST API Authentication${NC}"
            echo -e "${RED}  Status: $http_code${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ REST API Authentication${NC}"
        echo -e "${RED}  Error: Connection failed${NC}"
        return 1
    fi
}

# Check Docker container status
echo -e "${YELLOW}1. Docker Container Status${NC}"
echo -e "${GRAY}─────────────────────────────────────${NC}"

if container_status=$(docker ps --filter "name=geoserver" --format "{{.Status}}" 2>/dev/null); then
    if [ -n "$container_status" ]; then
        echo -e "${GREEN}✓ Container is running${NC}"
        echo -e "${GRAY}  Status: $container_status${NC}"
    else
        echo -e "${RED}✗ Container is not running${NC}"
        echo -e "${YELLOW}  Run: docker-compose up -d${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Docker command failed${NC}"
    exit 1
fi

echo ""

# Check web interface
echo -e "${YELLOW}2. Web Interface Checks${NC}"
echo -e "${GRAY}─────────────────────────────────────${NC}"

web_ok=0
wms_ok=0
wfs_ok=0

test_endpoint "$GEOSERVER_URL/web/" "Web Interface" && web_ok=1
test_endpoint "$GEOSERVER_URL/wms?service=wms&version=1.1.0&request=GetCapabilities" "WMS Service" && wms_ok=1
test_endpoint "$GEOSERVER_URL/wfs?service=wfs&version=1.1.0&request=GetCapabilities" "WFS Service" && wfs_ok=1

echo ""

# Check REST API (if credentials provided)
if [ -n "$ADMIN_PASSWORD" ]; then
    echo -e "${YELLOW}3. REST API Checks${NC}"
    echo -e "${GRAY}─────────────────────────────────────${NC}"
    
    test_auth_endpoint "$GEOSERVER_URL/rest/about/version.json" "$ADMIN_USER" "$ADMIN_PASSWORD"
    
    echo ""
fi

# Check container resources
echo -e "${YELLOW}4. Resource Usage${NC}"
echo -e "${GRAY}─────────────────────────────────────${NC}"

if stats=$(docker stats geoserver --no-stream --format "{{.CPUPerc}}|{{.MemUsage}}|{{.NetIO}}|{{.BlockIO}}" 2>/dev/null); then
    IFS='|' read -r cpu mem net block <<< "$stats"
    
    echo -e "${GRAY}  CPU Usage:     $cpu${NC}"
    echo -e "${GRAY}  Memory Usage:  $mem${NC}"
    echo -e "${GRAY}  Network I/O:   $net${NC}"
    echo -e "${GRAY}  Block I/O:     $block${NC}"
else
    echo -e "${RED}✗ Failed to get container stats${NC}"
fi

echo ""

# Check data directory
echo -e "${YELLOW}5. Data Directory${NC}"
echo -e "${GRAY}─────────────────────────────────────${NC}"

# For Docker mount, check inside container
if docker exec geoserver test -d /opt/geoserver/data_dir 2>/dev/null; then
    dir_size=$(docker exec geoserver du -sh /opt/geoserver/data_dir 2>/dev/null | cut -f1)
    
    echo -e "${GREEN}✓ Data directory exists${NC}"
    echo -e "${GRAY}  Location: /opt/geoserver/data_dir${NC}"
    echo -e "${GRAY}  Size: $dir_size${NC}"
else
    echo -e "${RED}✗ Data directory not found${NC}"
fi

echo ""

# Summary
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Health Check Summary${NC}"
echo -e "${CYAN}========================================${NC}"

if [ $web_ok -eq 1 ] && [ $wms_ok -eq 1 ] && [ $wfs_ok -eq 1 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo ""
    echo -e "${CYAN}GeoServer is running at: $GEOSERVER_URL${NC}"
    exit 0
else
    echo -e "${RED}✗ Some checks failed!${NC}"
    echo ""
    echo -e "${YELLOW}Check the logs: docker-compose logs geoserver${NC}"
    exit 1
fi
