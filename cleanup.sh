#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}DevDocs Cleanup Script${NC}"
echo "This script removes redundant files and normalizes configurations."
echo ""

# Remove our created duplicate src and static directories
echo -e "${BLUE}Removing redundant directories...${NC}"
rm -rf src static

# Copy the correct wrangler.jsonc with KV ID to the devdocs-mcp folder
echo -e "${BLUE}Normalizing wrangler.jsonc configurations...${NC}"
cp -v wrangler.jsonc devdocs-mcp/wrangler.jsonc

# Update the content of cursor_mcp_settings.json and claude_mcp_settings.json
# to ensure they match between root and devdocs-mcp
echo -e "${BLUE}Normalizing MCP settings files...${NC}"
if [ -f "cursor_mcp_settings.json" ] && [ -f "devdocs-mcp/cursor_mcp_settings.json" ]; then
  cp -v cursor_mcp_settings.json devdocs-mcp/cursor_mcp_settings.json
fi

if [ -f "claude_mcp_settings.json" ] && [ -f "devdocs-mcp/claude_mcp_settings.json" ]; then
  cp -v claude_mcp_settings.json devdocs-mcp/claude_mcp_settings.json
fi

# Clean up duplicate scripts
echo -e "${BLUE}Removing unnecessary scripts...${NC}"
rm -f edit-package.bat deploy-mcp.bat 

# Make the setup scripts use the ones in devdocs-mcp
echo -e "${BLUE}Updating setup scripts to use devdocs-mcp versions...${NC}"
cat > setup.sh << 'EOF'
#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}DevDocs Setup Script${NC}"
echo "This script sets up and deploys the DevDocs MCP server."
echo ""

# Detect environment
IS_NIXOS=false
if command -v nix-shell &> /dev/null; then
  IS_NIXOS=true
  echo -e "${BLUE}NixOS environment detected.${NC}"
  
  # Use the Nix setup
  echo -e "${BLUE}Setting up using Nix environment...${NC}"
  cd devdocs-mcp
  ../nix-setup.sh
else
  # Regular setup
  echo -e "${BLUE}Setting up using standard environment...${NC}"
  cd devdocs-mcp
  ./setup.bat
fi
EOF

chmod +x setup.sh

cat > setup.bat << 'EOF'
@echo off
setlocal enabledelayedexpansion

echo [36mDevDocs Setup Script[0m
echo This script sets up and deploys the DevDocs MCP server.
echo.

cd devdocs-mcp
call setup.bat

endlocal
EOF

cat > deploy-mcp.sh << 'EOF'
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
EOF

chmod +x deploy-mcp.sh

echo -e "${GREEN}Cleanup complete!${NC}"
echo "The codebase is now optimized with redundant files removed."
echo "You can now use:"
echo -e "  ${GREEN}./setup.sh${NC} - To set up the MCP server"
echo -e "  ${GREEN}./deploy-mcp.sh${NC} - To deploy the MCP server" 