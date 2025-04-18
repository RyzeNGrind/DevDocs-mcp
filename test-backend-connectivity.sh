#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}DevDocs Backend Network Connectivity Test${NC}"

# Test if the backend container exists
if ! docker ps | grep -q devdocs-backend; then
  echo -e "${RED}Backend container not running. Please start it first.${NC}"
  exit 1
fi

# Install network tools if missing
echo -e "\n${BLUE}Installing network utilities in backend container...${NC}"
docker exec devdocs-backend sh -c "apt-get update && apt-get install -y dnsutils iproute2 --no-install-recommends && apt-get clean"

echo -e "\n${BLUE}Testing DNS resolution inside backend container...${NC}"
docker exec devdocs-backend sh -c "nslookup nix-community.github.io || true"
docker exec devdocs-backend sh -c "nslookup google.com || true"

echo -e "\n${BLUE}Testing HTTP connectivity inside backend container...${NC}"
docker exec devdocs-backend sh -c "curl -v --max-time 10 https://nix-community.github.io/NixOS-WSL/ 2>&1 | grep -E 'Connected|HTTP/'"
docker exec devdocs-backend sh -c "curl -v --max-time 10 https://example.com 2>&1 | grep -E 'Connected|HTTP/'"

echo -e "\n${BLUE}Testing Crawl4AI connectivity from backend container...${NC}"
docker exec devdocs-backend sh -c "curl -v --max-time 5 http://crawl4ai:11235/health 2>&1 | grep -E 'Connected|HTTP/'"

echo -e "\n${BLUE}Testing Python requests module inside backend container...${NC}"
docker exec devdocs-backend python3 -c "
import requests
try:
    r = requests.get('https://nix-community.github.io/NixOS-WSL/', timeout=10)
    print(f'Status code: {r.status_code}')
    print(f'Content length: {len(r.text)} characters')
    print('Connection successful!')
except Exception as e:
    print(f'Error: {e}')
"

echo -e "\n${BLUE}Testing environment variables in backend container...${NC}"
docker exec devdocs-backend sh -c "env | grep -E 'PROXY|DNS|CRAWL4AI'"

echo -e "\n${BLUE}Testing network configuration in backend container...${NC}"
docker exec devdocs-backend sh -c "ip route || true"
docker exec devdocs-backend sh -c "cat /etc/resolv.conf || true"

echo -e "\n${GREEN}Connectivity test completed.${NC}" 