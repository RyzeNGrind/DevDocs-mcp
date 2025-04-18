#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}DevDocs Inter-Service Communication Test${NC}"

# Test if the backend container exists
if ! docker ps | grep -q devdocs-backend; then
  echo -e "${RED}Backend container not running. Please start it first.${NC}"
  exit 1
fi

echo -e "\n${BLUE}Testing Backend to Crawl4AI communication...${NC}"
docker exec devdocs-backend sh -c "curl -s http://crawl4ai:11235/health | grep -q 'healthy' && echo -e '${GREEN}✓ Backend can reach Crawl4AI${NC}' || echo -e '${RED}✗ Backend cannot reach Crawl4AI${NC}'"

echo -e "\n${BLUE}Testing Backend to MCP communication...${NC}"
docker exec devdocs-backend sh -c "getent hosts mcp && echo -e '${GREEN}✓ Backend can resolve MCP container${NC}' || echo -e '${RED}✗ Backend cannot resolve MCP container${NC}'"

echo -e "\n${BLUE}Testing Frontend to Backend communication...${NC}"
docker exec devdocs-frontend sh -c "curl -s http://backend:24125/health | grep -q 'healthy' && echo -e '${GREEN}✓ Frontend can reach Backend${NC}' || echo -e '${RED}✗ Frontend cannot reach Backend${NC}'"

echo -e "\n${BLUE}Testing endpoint configuration...${NC}"
# Check if discover endpoint accepts POST
echo -e "Sending POST request to /api/discover endpoint..."
curl -s -X POST -H "Content-Type: application/json" -d '{"url":"https://example.com","depth":1}' http://localhost:24125/api/discover > /dev/null
if [ $? -eq 0 ]; then
  echo -e "${GREEN}✓ /api/discover endpoint accepts POST requests${NC}"
else
  echo -e "${RED}✗ /api/discover endpoint failed to process POST request${NC}"
fi

echo -e "\n${BLUE}Testing Crawl4AI connectivity...${NC}"
CRAWL4AI_RESPONSE=$(curl -s http://localhost:11235/health)
if [[ "$CRAWL4AI_RESPONSE" == *"healthy"* ]]; then
  echo -e "${GREEN}✓ Crawl4AI service is healthy${NC}"
else
  echo -e "${RED}✗ Crawl4AI service is not responding correctly${NC}"
  echo "Response: $CRAWL4AI_RESPONSE"
fi

echo -e "\n${BLUE}Testing Frontend service...${NC}"
if curl -s http://localhost:3001 | grep -q "DOCTYPE"; then
  echo -e "${GREEN}✓ Frontend service is responding with HTML${NC}"
else
  echo -e "${RED}✗ Frontend service is not responding with valid HTML${NC}"
fi

echo -e "\n${GREEN}Service communication test completed${NC}" 