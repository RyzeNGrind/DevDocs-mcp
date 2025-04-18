@echo off
setlocal enabledelayedexpansion

echo DevDocs MCP Server Setup
echo This script will help you set up and deploy your DevDocs MCP server to Cloudflare Workers.
echo.

REM Check for Node.js installation
where node >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Error: Node.js is not installed.
    echo Please install Node.js v18 or newer before continuing.
    exit /b 1
)

REM Check for npm installation
where npm >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Error: npm is not installed.
    echo Please install npm before continuing.
    exit /b 1
)

REM Check for wrangler installation
where wrangler >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Installing Wrangler CLI...
    call npm install -g wrangler
)

REM Install dependencies
echo Installing project dependencies...
call npm install

REM Login to Cloudflare
echo Logging in to Cloudflare...
call wrangler login

REM Create KV namespace for OAuth
echo Creating KV namespace for OAuth...
echo This will be used to store OAuth tokens for authentication.
FOR /F "tokens=*" %%g IN ('wrangler kv:namespace create OAUTH_KV') do (SET KV_OUTPUT=%%g)

REM Parse the output to get the KV ID
echo !KV_OUTPUT! | findstr /R /C:"id = \"[^\"]*\"" > temp.txt
set /p KV_LINE=<temp.txt
del temp.txt

for /f "tokens=3 delims= " %%a in ("!KV_LINE!") do (
    set KV_ID=%%a
    set KV_ID=!KV_ID:"=!
)

REM Update wrangler.jsonc with KV namespace ID
echo Updating wrangler.jsonc with KV namespace ID...
powershell -Command "(Get-Content wrangler.jsonc) -replace '<YOUR_KV_NAMESPACE_ID>', '!KV_ID!' | Set-Content wrangler.jsonc"

REM Set up GitHub OAuth
echo Setting up GitHub OAuth...
echo You need to create a GitHub OAuth App at: https://github.com/settings/developers
echo.
echo Use the following settings:
echo   - Application name: DevDocs MCP Server
echo   - Homepage URL: Your worker URL (e.g., https://devdocs-mcp.your-account.workers.dev)
echo   - Authorization callback URL: Your worker callback URL (e.g., https://devdocs-mcp.your-account.workers.dev/callback)
echo.

set /p SETUP_OAUTH="Would you like to set up GitHub OAuth now? (y/n): "
if /i "%SETUP_OAUTH%"=="y" (
    set /p GITHUB_CLIENT_ID="Please enter your GitHub OAuth Client ID: "
    call wrangler secret put GITHUB_CLIENT_ID
    
    set /p GITHUB_CLIENT_SECRET="Please enter your GitHub OAuth Client Secret: "
    call wrangler secret put GITHUB_CLIENT_SECRET
    
    echo GitHub OAuth configured successfully!
) else (
    echo You can set up GitHub OAuth later by running:
    echo   wrangler secret put GITHUB_CLIENT_ID
    echo   wrangler secret put GITHUB_CLIENT_SECRET
)

REM Deploy
echo Ready to deploy to Cloudflare Workers!
set /p DEPLOY_NOW="Would you like to deploy now? (y/n): "
if /i "%DEPLOY_NOW%"=="y" (
    echo Deploying to Cloudflare Workers...
    call npm run deploy
    
    echo Deployment complete!
    echo.
    echo Your DevDocs MCP server is now available at your workers.dev subdomain.
    echo You can connect Claude Desktop to it using:
    echo.
    echo   npx mcp-remote https://YOUR-WORKER-DOMAIN.workers.dev/sse
) else (
    echo You can deploy later by running: npm run deploy
)

echo.
echo Setup complete!
echo For more information, refer to the README.md file.

endlocal