#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}DevDocs Comprehensive Service Restart${NC}"

# Make sure all test scripts are executable
chmod +x test-backend-connectivity.sh
chmod +x test-service-communication.sh

# Check if docker is running
echo -e "\n${BLUE}Checking if Docker is running...${NC}"
if ! docker info > /dev/null 2>&1; then
  echo -e "${RED}Docker is not running. Please start Docker first.${NC}"
  exit 1
fi

# Stop all running containers
echo -e "\n${BLUE}Stopping all running DevDocs containers...${NC}"
docker-compose down || true

# Remove any dangling volumes
echo -e "\n${BLUE}Removing dangling volumes...${NC}"
docker volume prune -f || true

# Create necessary directories
echo -e "\n${BLUE}Creating necessary directories...${NC}"
mkdir -p storage/markdown
mkdir -p storage/html
mkdir -p logs
mkdir -p crawl_results

# Set permissions for directories
echo -e "\n${BLUE}Setting permissions for directories...${NC}"
chmod -R 777 storage logs crawl_results || true

# Rebuild and start containers
echo -e "\n${BLUE}Rebuilding and starting containers with updated configuration...${NC}"
docker-compose build --no-cache
docker-compose up -d

# Wait for services to start
echo -e "\n${BLUE}Waiting for services to start up...${NC}"
for i in {1..30}; do
  echo -n "."
  sleep 1
done
echo ""

# Test backend connectivity
echo -e "\n${BLUE}Testing backend connectivity...${NC}"
./test-backend-connectivity.sh

# Test service communication
echo -e "\n${BLUE}Testing service communication...${NC}"
./test-service-communication.sh

# Check service status
echo -e "\n${BLUE}Checking service status...${NC}"
if [ -f "check-hybrid-services.sh" ]; then
  ./check-hybrid-services.sh
else
  echo -e "${YELLOW}check-hybrid-services.sh not found, skipping service check${NC}"
fi

echo -e "\n${BLUE}Testing /api/discover endpoint with a real URL...${NC}"
curl -X POST -H "Content-Type: application/json" -d '{"url":"https://nix-community.github.io/NixOS-WSL/","depth":2}' http://localhost:24125/api/discover

echo -e "\n${GREEN}Services have been restarted and tested!${NC}"
echo -e "${GREEN}You can now access the frontend at http://localhost:3001${NC}"
echo -e "${YELLOW}Note: If you encounter any issues, check the logs using:${NC}"
echo -e "  docker logs devdocs-backend"
echo -e "  docker logs devdocs-frontend"
echo -e "  docker logs devdocs-crawl4ai" 