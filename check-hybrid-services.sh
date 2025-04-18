#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}DevDocs Hybrid Services Status Check${NC}"
echo "Checking status of all required services..."
echo ""

# Check MCP server (Cloudflare Worker)
echo -e "${BLUE}Checking MCP server...${NC}"
MCP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://devdocs-mcp.vidurshan-sribala.workers.dev/status 2>/dev/null || echo "error")

if [ "$MCP_STATUS" == "200" ]; then
    echo -e "${GREEN}MCP server is running properly.${NC}"
    MCP_RESPONSE=$(curl -s https://devdocs-mcp.vidurshan-sribala.workers.dev/status)
    echo "Response: $MCP_RESPONSE"
else
    echo -e "${RED}MCP server is not responding correctly (Status: $MCP_STATUS).${NC}"
    echo "Please deploy it using ./deploy-mcp.sh"
fi

# Check Backend service
echo -e "\n${BLUE}Checking Backend service...${NC}"
BACKEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:24125/api/status 2>/dev/null || echo "error")

if [ "$BACKEND_STATUS" == "200" ] || [ "$BACKEND_STATUS" == "404" ]; then
    echo -e "${GREEN}Backend service appears to be running (Status: $BACKEND_STATUS).${NC}"
    # Try another endpoint if /api/status returns 404
    if [ "$BACKEND_STATUS" == "404" ]; then
        echo -e "${YELLOW}Note: /api/status endpoint not found. Trying /api/discover...${NC}"
        DISCOVER_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:24125/api/discover 2>/dev/null || echo "error")
        echo "Discover endpoint status: $DISCOVER_STATUS"
    fi
else
    echo -e "${RED}Backend service is not responding (Status: $BACKEND_STATUS).${NC}"
    echo "Please check if backend is running on port 24125."
fi

# Check Frontend service
echo -e "\n${BLUE}Checking Frontend service...${NC}"
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3001 2>/dev/null || echo "error")

if [ "$FRONTEND_STATUS" == "200" ]; then
    echo -e "${GREEN}Frontend service is running properly.${NC}"
else
    echo -e "${RED}Frontend service is not responding (Status: $FRONTEND_STATUS).${NC}"
    echo "Please check if frontend is running on port 3001."
fi

# Check Crawl4AI service
echo -e "\n${BLUE}Checking Crawl4AI service...${NC}"
CRAWL4AI_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:11235/health 2>/dev/null || echo "error")

if [ "$CRAWL4AI_STATUS" == "200" ]; then
    echo -e "${GREEN}Crawl4AI service is running properly.${NC}"
else
    echo -e "${RED}Crawl4AI service is not responding (Status: $CRAWL4AI_STATUS).${NC}"
    echo "Please check if Crawl4AI container is running on port 11235."
    echo "Docker status:"
    docker ps | grep 11235 || echo "No container found on port 11235"
fi

# Overall status
echo -e "\n${BLUE}Overall Status:${NC}"
if [[ "$MCP_STATUS" == "200" && ("$BACKEND_STATUS" == "200" || "$BACKEND_STATUS" == "404") && "$FRONTEND_STATUS" == "200" && "$CRAWL4AI_STATUS" == "200" ]]; then
    echo -e "${GREEN}All services appear to be running correctly!${NC}"
else
    echo -e "${RED}Some services have issues. Please check the details above.${NC}"
fi 