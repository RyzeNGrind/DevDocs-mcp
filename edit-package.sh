#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}DevDocs MCP Package.json Update Script${NC}"
echo "This script will update package.json with MCP dependencies."
echo ""

# Backup the current package.json
echo -e "${BLUE}Backing up current package.json...${NC}"
cp package.json package.json.bak

# Create a new package.json with merged dependencies
cat > package.json << 'EOF'
{
  "name": "devdocs-explorer",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "deploy-mcp": "cd src && wrangler deploy",
    "dev-mcp": "cd src && wrangler dev",
    "start-mcp": "cd src && wrangler dev"
  },
  "dependencies": {
    "@cloudflare/workers-oauth-provider": "^0.0.2",
    "@emotion/react": "^11.14.0",
    "@emotion/styled": "^11.14.0",
    "@modelcontextprotocol/sdk": "^1.7.0",
    "@mui/icons-material": "^6.4.0",
    "@mui/material": "^6.4.0",
    "@radix-ui/react-checkbox": "^1.1.5",
    "@radix-ui/react-dialog": "^1.1.7",
    "@radix-ui/react-popover": "^1.1.7",
    "@radix-ui/react-scroll-area": "^1.2.2",
    "@radix-ui/react-slot": "^1.1.1",
    "@radix-ui/react-toast": "^1.2.6",
    "@radix-ui/react-tooltip": "^1.2.0",
    "agents": "^0.0.53",
    "class-variance-authority": "^0.7.1",
    "clsx": "^2.1.1",
    "hono": "^4.7.4",
    "lucide-react": "^0.454.0",
    "marked": "^12.0.0",
    "next": "15.1.4",
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "showdown": "^2.1.0",
    "tailwind-merge": "^2.5.5",
    "tailwindcss-animate": "^1.0.7",
    "zod": "^3.24.2"
  },
  "devDependencies": {
    "@cloudflare/workers-types": "^4.20250418.0",
    "@types/node": "^22",
    "@types/react": "^19.0.0",
    "@types/react-dom": "^19.0.0",
    "autoprefixer": "^10.4.20",
    "postcss": "^8",
    "tailwindcss": "^3.4.17",
    "typescript": "^5.5.2",
    "wrangler": "^4.12.0"
  }
}
EOF

echo -e "${GREEN}Package.json updated successfully!${NC}"
echo "The original file has been backed up as package.json.bak"
echo "You can now run 'npm install' to install all dependencies." 