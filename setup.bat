@echo off
setlocal enabledelayedexpansion

echo [36mDevDocs Setup Script[0m
echo This script sets up and deploys the DevDocs MCP server.
echo.

cd devdocs-mcp
call setup.bat

endlocal
