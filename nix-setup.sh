#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}Setting up DevDocs MCP Server in NixOS environment...${NC}"

# Ensure we're in the correct directory
if [ ! -d "./devdocs-mcp" ]; then
  cd ..
  if [ ! -d "./devdocs-mcp" ]; then
    echo -e "${RED}Error: Unable to find devdocs-mcp directory${NC}"
    exit 1
  fi
fi

# Use nix-shell to set up the environment
echo -e "${BLUE}Installing dependencies using Nix...${NC}"
cd devdocs-mcp
nix-shell -p nodejs_20 nodePackages.wrangler nodePackages.typescript --command "npm install"

# Make sure the .dev.vars file exists
if [ ! -f ".dev.vars" ]; then
  echo -e "${BLUE}Creating .dev.vars file...${NC}"
  cat << EOF > .dev.vars
OAUTH_CLIENT_ID=your_oauth_client_id
OAUTH_CLIENT_SECRET=your_oauth_client_secret
AUTH_SECRET=your_auth_secret
NEXT_PUBLIC_APP_URL=http://localhost:8787
SITE_URL=http://localhost:8787
OPENAI_API_KEY=your_openai_api_key
EOF
  echo -e "${GREEN}Created .dev.vars file. Please update it with your actual credentials.${NC}"
else
  echo -e "${BLUE}.dev.vars file already exists. Skipping...${NC}"
fi

# Setup complete
echo -e "${GREEN}DevDocs MCP Server setup complete!${NC}"
echo "To develop locally, run: cd devdocs-mcp && npx wrangler dev"
echo "To deploy to Cloudflare Workers, run: ./deploy-mcp.sh" 