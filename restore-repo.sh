#!/bin/bash

# Script to restore files deleted by rsync --delete command
echo "Starting repository restoration..."

# First, unstage all changes to prevent them from being committed
git reset HEAD

# Restore all the deleted tracked files from the last commit
echo "Restoring deleted files from git..."
git checkout -- Dockerfile.backend Dockerfile.frontend Dockerfile.mcp LICENSE README.md check_crawl4ai.sh check_mcp_health.sh claude_mcp_settings.json components.json debug_crawl4ai.sh docker-compose.yml docker-start.bat docker-start.sh docker-strategy.md next.config.mjs package-lock.json package.json postcss.config.mjs restart_and_test_mcp.sh start.bat start.ps1 start.sh tailwind.config.ts test_crawl4ai.py test_from_container.sh tsconfig.json view_result.sh

# Restore original versions of modified files
echo "Restoring modified files from git..."
git checkout -- instruct-worker.md devdocs-mcp/.gitignore devdocs-mcp/README.md devdocs-mcp/claude_mcp_settings.json devdocs-mcp/cursor_mcp_settings.json devdocs-mcp/setup.bat devdocs-mcp/setup.sh devdocs-mcp/src/app.ts devdocs-mcp/src/integrations.ts devdocs-mcp/tsconfig.json devdocs-mcp/wrangler.jsonc

# Keep the new files you want to preserve
echo "Keeping new files (NIXOS_README.md, flake.nix, nix-setup.sh, shell.nix)..."
# These files will remain as they are

echo "Repository restoration complete. Run 'git status' to verify the state."
echo "You may need to manually review any remaining issues." 