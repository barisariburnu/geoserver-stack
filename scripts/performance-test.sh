#!/bin/bash
# GeoServer Performance Test Script
# Description: Performs load testing on GeoServer endpoints

set -e

GEOSERVER_URL="${GEOSERVER_URL:-http://localhost:8080/geoserver}"
REQUESTS="${REQUESTS:-100}"
CONCURRENT="${CONCURRENT:-10}"
TEST_TYPE="${TEST_TYPE:-wms}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}GeoServer Performance Test${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo -e "${GRAY}  URL:              $GEOSERVER_URL${NC}"
echo -e "${GRAY}  Test Type:        $TEST_TYPE${NC}"
echo -e "${GRAY}  Total Requests:   $REQUESTS${NC}"
echo -e "${GRAY}  Concurrent:       $CONCURRENT${NC}"
echo ""

# Define test endpoints
case "$TEST_TYPE" in
    wms)
        TEST_URL="$GEOSERVER_URL/wms?service=WMS&version=1.1.0&request=GetCapabilities"
        ;;
    wfs)
        TEST_URL="$GEOSERVER_URL/wfs?service=WFS&version=1.1.0&request=GetCapabilities"
        ;;
    rest)
        TEST_URL="$GEOSERVER_URL/rest/about/version.json"
        ;;
    *)
        echo -e "${RED}✗ Invalid test type. Use: wms, wfs, or rest${NC}"
        exit 1
        ;;
esac

echo -e "${CYAN}Testing endpoint: $TEST_URL${NC}"
echo ""

# Check if Apache Bench (ab) is available
if ! command -v ab &> /dev/null; then
    echo -e "${RED}✗ Apache Bench (ab) not found${NC}"
    echo -e "${YELLOW}  Install: sudo apt-get install apache2-utils (Debian/Ubuntu)${NC}"
    echo -e "${YELLOW}           or yum install httpd-tools (RHEL/CentOS)${NC}"
    exit 1
fi

# Run performance test
echo -e "${YELLOW}Running tests...${NC}"
echo ""

# Run Apache Bench
ab -n "$REQUESTS" -c "$CONCURRENT" -q "$TEST_URL" > /tmp/geoserver_perf_test.txt 2>&1

# Parse results
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Test Results${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Extract key metrics
TOTAL_REQUESTS=$(grep "Complete requests:" /tmp/geoserver_perf_test.txt | awk '{print $3}')
FAILED_REQUESTS=$(grep "Failed requests:" /tmp/geoserver_perf_test.txt | awk '{print $3}')
REQUESTS_PER_SEC=$(grep "Requests per second:" /tmp/geoserver_perf_test.txt | awk '{print $4}')
TIME_PER_REQUEST=$(grep "Time per request:" /tmp/geoserver_perf_test.txt | head -1 | awk '{print $4}')
TRANSFER_RATE=$(grep "Transfer rate:" /tmp/geoserver_perf_test.txt | awk '{print $3}')

# Connection times
MIN_TIME=$(grep -A 2 "Connection Times" /tmp/geoserver_perf_test.txt | grep "Total:" | awk '{print $2}')
MEAN_TIME=$(grep -A 2 "Connection Times" /tmp/geoserver_perf_test.txt | grep "Total:" | awk '{print $3}')
MEDIAN_TIME=$(grep -A 2 "Connection Times" /tmp/geoserver_perf_test.txt | grep "Total:" | awk '{print $5}')
MAX_TIME=$(grep -A 2 "Connection Times" /tmp/geoserver_perf_test.txt | grep "Total:" | awk '{print $6}')

# Percentages
PERCENT_50=$(grep "50%" /tmp/geoserver_perf_test.txt | awk '{print $2}')
PERCENT_95=$(grep "95%" /tmp/geoserver_perf_test.txt | awk '{print $2}')
PERCENT_99=$(grep "99%" /tmp/geoserver_perf_test.txt | awk '{print $2}')

# Calculate success rate
SUCCESS_REQUESTS=$((TOTAL_REQUESTS - FAILED_REQUESTS))
SUCCESS_RATE=$(awk "BEGIN {printf \"%.2f\", ($SUCCESS_REQUESTS / $TOTAL_REQUESTS) * 100}")

echo -e "${YELLOW}Request Statistics:${NC}"
echo -e "${GRAY}  Total Requests:    $TOTAL_REQUESTS${NC}"
echo -e "${GREEN}  Successful:        $SUCCESS_REQUESTS ($SUCCESS_RATE%)${NC}"

if [ "$FAILED_REQUESTS" -eq 0 ]; then
    echo -e "${GRAY}  Failed:            $FAILED_REQUESTS (0.00%)${NC}"
else
    FAIL_RATE=$(awk "BEGIN {printf \"%.2f\", ($FAILED_REQUESTS / $TOTAL_REQUESTS) * 100}")
    echo -e "${RED}  Failed:            $FAILED_REQUESTS ($FAIL_RATE%)${NC}"
fi

echo ""

echo -e "${YELLOW}Response Times (ms):${NC}"
echo -e "${GRAY}  Mean:              $MEAN_TIME${NC}"
echo -e "${GRAY}  Median:            $MEDIAN_TIME${NC}"
echo -e "${GRAY}  Min:               $MIN_TIME${NC}"
echo -e "${GRAY}  Max:               $MAX_TIME${NC}"
echo -e "${GRAY}  50th Percentile:   $PERCENT_50${NC}"
echo -e "${GRAY}  95th Percentile:   $PERCENT_95${NC}"
echo -e "${GRAY}  99th Percentile:   $PERCENT_99${NC}"
echo ""

echo -e "${YELLOW}Performance:${NC}"
echo -e "${GRAY}  Requests/Second:   $REQUESTS_PER_SEC${NC}"
echo -e "${GRAY}  Time/Request:      $TIME_PER_REQUEST ms${NC}"
echo -e "${GRAY}  Transfer Rate:     $TRANSFER_RATE KB/sec${NC}"
echo ""

# Performance assessment
AVG_TIME=$(echo "$MEAN_TIME" | cut -d. -f1)

if [ "$AVG_TIME" -lt 100 ]; then
    echo -e "${GREEN}✓ Excellent performance!${NC}"
elif [ "$AVG_TIME" -lt 500 ]; then
    echo -e "${YELLOW}✓ Good performance${NC}"
else
    echo -e "${RED}⚠ Performance may need optimization${NC}"
fi

echo ""
echo -e "${CYAN}========================================${NC}"

# Clean up
rm -f /tmp/geoserver_perf_test.txt
