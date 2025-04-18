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
