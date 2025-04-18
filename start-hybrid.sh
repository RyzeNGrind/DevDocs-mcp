#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}DevDocs Hybrid Setup Script${NC}"
echo "This script sets up a hybrid deployment with:"
echo "- MCP Server: Cloudflare Workers (Remote)"
echo "- Frontend UI & Crawl4AI: Docker Compose (Local)"
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null || ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Error: Docker and docker-compose are required for this setup.${NC}"
    exit 1
fi

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

# Create local files directory if not exists
mkdir -p storage/markdown

# Start the local services
echo -e "${BLUE}Starting frontend and crawl4ai services...${NC}"
docker-compose -f docker/compose/hybrid-compose.yml up -d

echo -e "${GREEN}Hybrid setup started successfully!${NC}"
echo "Access your services at:"
echo "- Frontend UI: http://localhost:3001"
echo "- Crawl4AI Service: http://localhost:11235"
echo "- MCP Server: https://devdocs-mcp.vidurshan-sribala.workers.dev"
echo ""
echo "To add documentation, use the Crawl4AI service:"
echo "curl -X POST http://localhost:11235/crawl -H \"Content-Type: application/json\" -d '{\"url\": \"https://docs-url.com\", \"selector\": \"main\"}'"
echo ""
echo "To test MCP with your editor, update your editor's MCP settings to use:"
echo "https://devdocs-mcp.vidurshan-sribala.workers.dev/mcp" 