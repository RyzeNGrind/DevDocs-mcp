#!/usr/bin/env bash
# Test script for MCP server with inspector
set -e

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "jq is required but not installed. Please install it first."
    exit 1
fi

# Set colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting MCP Server Test${NC}"

# Check if MCP server is running
MCP_URL="http://localhost:8787"
MCP_SSE_URL="$MCP_URL/sse"

echo -e "Checking if MCP server is running at $MCP_URL..."
if ! curl -s --head $MCP_URL > /dev/null; then
    echo -e "${RED}MCP server is not running at $MCP_URL${NC}"
    echo -e "Would you like to start the MCP server now? (y/n)"
    read -r answer
    if [[ "$answer" == "y" ]]; then
        echo -e "Starting MCP server in the background..."
        (cd devdocs-mcp && npx wrangler dev --port 8787) &
        MCP_PID=$!
        # Wait for the server to start
        echo -e "Waiting for MCP server to start..."
        sleep 5
    else
        echo -e "Please start the MCP server first with:"
        echo -e "  cd devdocs-mcp && npx wrangler dev"
        exit 1
    fi
fi

echo -e "${GREEN}MCP server is running at $MCP_URL${NC}"

# Start the MCP Inspector
echo -e "${YELLOW}Starting MCP Inspector...${NC}"
echo -e "When the inspector opens, connect to: $MCP_SSE_URL"
npx @modelcontextprotocol/inspector

# If we started the MCP server, kill it
if [[ -n "$MCP_PID" ]]; then
    echo -e "Stopping MCP server..."
    kill $MCP_PID
fi

echo -e "${GREEN}Test complete.${NC}" 