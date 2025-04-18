#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Restarting DevDocs services with network connectivity fixes${NC}"

# Make sure our test script is executable
chmod +x test-backend-connectivity.sh

# Stop all running containers
echo -e "\n${BLUE}Stopping all running DevDocs containers...${NC}"
docker-compose down || true

# Remove any dangling volumes
echo -e "\n${BLUE}Removing dangling volumes...${NC}"
docker volume prune -f

# Rebuild and start containers
echo -e "\n${BLUE}Rebuilding and starting containers with updated configuration...${NC}"
docker-compose build --no-cache backend
docker-compose up -d

# Wait for services to start
echo -e "\n${BLUE}Waiting for services to start up...${NC}"
sleep 10

# Test backend connectivity
echo -e "\n${BLUE}Testing backend connectivity...${NC}"
./test-backend-connectivity.sh

# Check service status
echo -e "\n${BLUE}Checking service status...${NC}"
if [ -f "check-hybrid-services.sh" ]; then
  ./check-hybrid-services.sh
else
  echo -e "${YELLOW}check-hybrid-services.sh not found, skipping service check${NC}"
fi

echo -e "\n${GREEN}Services restarted with network connectivity fixes!${NC}"
echo -e "${GREEN}You can now try crawling your URL again.${NC}" 