#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}DevDocs MCP Server Deployment Script${NC}"
echo "This script will deploy your DevDocs MCP server to Cloudflare Workers."
echo ""

# Check if Nix is installed
if command -v nix-shell &> /dev/null; then
  echo -e "${BLUE}NixOS environment detected.${NC}"
  echo "Using Nix shell for deployment..."
  
  # Run the deployment within a Nix shell
  cd devdocs-mcp
  nix-shell -p nodejs_20 nodePackages.wrangler nodePackages.typescript --command "npm install && npx wrangler deploy"
else
  # Regular deployment
  echo -e "${BLUE}Regular environment detected.${NC}"
  echo "Deploying directly with wrangler..."
  
  cd devdocs-mcp
  npm install && npx wrangler deploy
fi

echo -e "${GREEN}Deployment complete!${NC}"
echo "Your MCP server is now available at: https://devdocs-mcp.vidurshan-sribala.workers.dev/"
echo ""
echo "You can test it by visiting the URL in your browser."
