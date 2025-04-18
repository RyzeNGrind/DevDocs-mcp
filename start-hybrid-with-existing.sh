#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}DevDocs Hybrid Setup Script (Using Existing Crawl4AI)${NC}"
echo "This script sets up a hybrid deployment with:"
echo "- MCP Server: Cloudflare Workers (Remote)"
echo "- Backend API: Running locally on port 24125"
echo "- Frontend UI: Running locally on port 3000"
echo "- Crawl4AI: Using existing container at port 11235"
echo ""

# Check if the deployed worker is up
echo -e "${BLUE}Checking MCP server status...${NC}"
MCP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://devdocs-mcp.vidurshan-sribala.workers.dev/status || echo "error")

if [ "$MCP_STATUS" != "200" ]; then
    echo -e "${RED}Error: MCP server is not responding correctly. Deploy it first using ./deploy-mcp.sh${NC}"
    read -p "Do you want to deploy it now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ./deploy-mcp.sh
    else
        exit 1
    fi
fi

# Check if Crawl4AI is running
echo -e "${BLUE}Checking Crawl4AI container...${NC}"
CRAWL4AI_RUNNING=$(docker ps | grep "11235->11235" || echo "")

if [ -z "$CRAWL4AI_RUNNING" ]; then
    echo -e "${RED}Warning: Crawl4AI container not found on port 11235.${NC}"
    echo "The existing Crawl4AI at port 11235 is required for this setup."
    exit 1
else
    echo -e "${GREEN}Existing Crawl4AI container detected at port 11235.${NC}"
fi

# Create local files directory if not exists
mkdir -p storage/markdown

# Start the backend service
echo -e "${BLUE}Starting backend service...${NC}"
cd backend
npm install
PORT=24125 NODE_ENV=development npm run dev &
BACKEND_PID=$!
echo -e "${GREEN}Backend service started with PID: ${BACKEND_PID}${NC}"
cd ..

# Start the frontend service locally
echo -e "${BLUE}Starting Next.js frontend...${NC}"
cd app
npm install
NEXT_PUBLIC_API_URL=http://localhost:24125 \
NEXT_PUBLIC_CRAWL4AI_URL=http://localhost:11235 \
NEXT_PUBLIC_MCP_URL=https://devdocs-mcp.vidurshan-sribala.workers.dev \
npm run dev &
FRONTEND_PID=$!
echo -e "${GREEN}Frontend service started with PID: ${FRONTEND_PID}${NC}"
cd ..

# Set up environment for editor
echo -e "${BLUE}Setting up editor environment...${NC}"
mkdir -p /tmp/agent_logs
touch /tmp/agent_logs/mcp_requests.log
chmod 666 /tmp/agent_logs/mcp_requests.log

echo -e "${GREEN}Hybrid setup started successfully!${NC}"
echo "Access your services at:"
echo "- Frontend UI: http://localhost:3000"
echo "- Backend API: http://localhost:24125"
echo "- Crawl4AI Service: http://localhost:11235"
echo "- MCP Server: https://devdocs-mcp.vidurshan-sribala.workers.dev"
echo ""
echo "To monitor MCP requests, run:"
echo "tail -f /tmp/agent_logs/mcp_requests.log"
echo ""
echo "To add documentation, use the Crawl4AI service:"
echo "curl -X POST http://localhost:11235/crawl -H \"Content-Type: application/json\" -d '{\"url\": \"https://docs-url.com\", \"selector\": \"main\"}'"
echo ""
echo "To test MCP with your editor, update your editor's MCP settings to use:"
echo "https://devdocs-mcp.vidurshan-sribala.workers.dev/mcp"
echo ""
echo "Press Ctrl+C to stop the services"

# Trap to ensure clean shutdown
trap 'echo -e "${BLUE}Shutting down services...${NC}"; kill $BACKEND_PID $FRONTEND_PID 2>/dev/null; echo -e "${GREEN}Done!${NC}"; exit' INT TERM

# Wait for user to press Ctrl+C
wait 