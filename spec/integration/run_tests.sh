#!/bin/bash

# Integration Test Runner for Seerr Notification Plugin
# Spins up signal-cli-rest-api, runs BATS tests, then cleans up

set -e

cd "$(dirname "$0")/../.."

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

API_URL="${API_URL:-http://localhost:18080}"
COMPOSE_FILE="spec/integration/docker-compose.yml"

cleanup() {
    echo ""
    echo -e "${BLUE}Cleaning up...${NC}"
    docker compose -f "$COMPOSE_FILE" down --volumes --remove-orphans 2>/dev/null || true
    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

trap cleanup EXIT

echo ""
echo "============================================"
echo "  Seerr Notification Integration Tests"
echo "============================================"
echo ""

# Check if bats is installed
if ! command -v bats &> /dev/null; then
    echo -e "${RED}Error: bats is not installed${NC}"
    echo ""
    echo "Install bats:"
    echo "  macOS: brew install bats-core"
    echo "  Ubuntu: sudo apt-get install bats"
    echo ""
    exit 1
fi

# Check if Docker is available
if ! docker info &> /dev/null; then
    echo -e "${RED}Error: Docker is not running${NC}"
    echo ""
    echo "Please start Docker Desktop first."
    echo ""
    exit 1
fi

if [ "${SKIP_BUILD}" = "true" ]; then
    echo -e "${BLUE}Skipping build (using existing artifact)${NC}"
else
    echo -e "${BLUE}Building plugin bundle...${NC}"
    if ! make build > /dev/null 2>&1; then
        echo -e "${RED}Error: Build failed${NC}"
        echo ""
        echo "Run 'make build' manually to see detailed error."
        exit 1
    fi
    echo -e "${GREEN}✓ Build complete${NC}"
fi

DIST_PATH="dist/seerr-notification"
if [ ! -f "${DIST_PATH}/seerr-notification.lua" ] || [ ! -f "${DIST_PATH}/seerr-notification.def" ]; then
    echo -e "${RED}Error: Build artifacts not found in ${DIST_PATH}/${NC}"
    echo ""
    echo "Expected files:"
    echo "  - seerr-notification.lua"
    echo "  - seerr-notification.def"
    exit 1
fi
echo -e "${GREEN}✓ Build artifacts verified${NC}"

# Check if container is already running
CONTAINER_NAME="signal-cli-rest-api-test"
if docker ps -a -q -f name="^${CONTAINER_NAME}$" | grep -q .; then
    echo -e "${YELLOW}Found existing container ${CONTAINER_NAME}${NC}"
    echo -e "${BLUE}Cleaning up existing container...${NC}"
    docker compose -f "$COMPOSE_FILE" down --volumes --remove-orphans
    sleep 2
fi

# Check if port is already in use and attempt cleanup
if lsof -Pi :18080 -sTCP:LISTEN -t >/dev/null 2>&1; then
    PID_INFO=$(lsof -Pi :18080 -sTCP:LISTEN | tail -n +2)
    
    if echo "$PID_INFO" | grep -q "docker"; then
        echo -e "${YELLOW}Port 18080 is held by Docker (likely orphaned resource)${NC}"
        echo -e "${BLUE}Attempting Docker cleanup...${NC}"
        docker compose -f "$COMPOSE_FILE" down --volumes --remove-orphans 2>/dev/null || true
        sleep 3
        
        if lsof -Pi :18080 -sTCP:LISTEN -t >/dev/null 2>&1; then
            echo -e "${RED}Port 18080 still in use after Docker cleanup${NC}"
            echo ""
            echo "Process details:"
            lsof -Pi :18080 -sTCP:LISTEN
            echo ""
            echo "Try: docker system prune -f"
            exit 1
        fi
        echo -e "${GREEN}✓ Port 18080 released${NC}"
    else
        echo -e "${RED}Error: Port 18080 is in use by non-Docker process${NC}"
        echo ""
        echo "Process details:"
        echo "$PID_INFO"
        echo ""
        echo "Please stop the service using port 18080 and try again."
        exit 1
    fi
fi

# Start the container
echo -e "${BLUE}Starting signal-cli-rest-api...${NC}"
docker compose -f "$COMPOSE_FILE" up -d --remove-orphans

# Wait for API to be ready
echo -e "${YELLOW}Waiting for API to be ready...${NC}"
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s -f "${API_URL}/v1/about" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Signal API is ready${NC}"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo -e "${RED}Error: API failed to start after ${MAX_RETRIES} attempts${NC}"
        echo ""
        echo "Container logs:"
        docker compose -f "$COMPOSE_FILE" logs --tail=50
        exit 1
    fi
    sleep 1
    echo -n "."
done

echo ""
echo ""

# Run tests
echo -e "${YELLOW}Running integration tests...${NC}"
echo ""

bats spec/integration/seerr_notification.bats

echo ""
echo "============================================"
echo -e "${GREEN}✓ Integration tests complete!${NC}"
echo "============================================"
