# Debugging the DevDocs MCP Server

This guide explains how to debug the DevDocs MCP (Model Context Protocol) server, which is powered by Cloudflare Workers.

## Prerequisites

- Node.js 18.x or later
- npm or yarn
- [Wrangler CLI](https://developers.cloudflare.com/workers/wrangler/install-and-update/) (Cloudflare Workers CLI)
- VS Code (optional, for using the included debugging configurations)

## Local Development

### Using Nix Development Shell

The recommended way to develop and debug the MCP server is using the Nix development shell, which sets up all required dependencies:

```bash
# Enter the development shell
nix develop

# Start the MCP server
start-mcp

# In another terminal, test the MCP server
test-mcp
```

### Manual Development

If you prefer not to use Nix, you can manually set up your environment:

```bash
# Install dependencies
cd devdocs-mcp
npm install

# Start the MCP server
npx wrangler dev

# Test with the MCP Inspector
npx @modelcontextprotocol/inspector
```

## Using VS Code Debugging

We've included VS Code debugging configurations in `.vscode/launch.json`. To use them:

1. Open the project in VS Code
2. Go to the "Run and Debug" panel (Ctrl+Shift+D or Cmd+Shift+D)
3. Select "Debug MCP Server" from the dropdown
4. Press F5 to start debugging

You can set breakpoints in your code, and VS Code will pause execution when they're hit.

## Testing the MCP Server

The MCP server exposes tools that can be used by MCP clients. To test these tools:

1. Start the MCP server using either method above
2. Run the MCP Inspector:
   ```bash
   npx @modelcontextprotocol/inspector
   ```
3. Connect to `http://localhost:8787/sse` in the inspector
4. Click "List Tools" to see available tools
5. Test calling the tools from the inspector

## Troubleshooting

### Common Issues

- **CORS Errors**: If you see CORS errors in the console, make sure your MCP server is properly configured to accept requests from your client's origin.
- **Authentication Errors**: If using GitHub authentication, check that your OAuth app is correctly configured and the client ID and secret are properly set in `.dev.vars`.
- **Connection Issues**: Ensure the server is running and accessible at `http://localhost:8787`.

### Debugging Specific Components

#### Durable Objects

The MCP server uses Cloudflare Durable Objects for state management. To debug issues with state:

1. Enable verbose logging in your code
2. Check the Cloudflare Workers console for errors

#### Environment Variables

For local development, environment variables should be set in the `.dev.vars` file. Common required variables:

- `GITHUB_CLIENT_ID` and `GITHUB_CLIENT_SECRET` (if using GitHub auth)
- `DEVDOCS_API_URL` (pointing to your backend API)

## Extension Points

The MCP server is designed to be extensible. Key extension points:

1. **Add new tools** by modifying `src/index.ts` to add new functionality to the MCP server
2. **Customize authentication** by implementing your own provider
3. **Add custom state management** by extending the DocState interface

## Advanced Debugging

For more advanced debugging, you can use the Wrangler CLI with additional flags:

```bash
# Enable verbose logging
npx wrangler dev --verbose

# Inspect the Durable Object storage
npx wrangler do list MCP_OBJECT
```

## Additional Resources

- [Model Context Protocol Specification](https://github.com/modelcontextprotocol/mcp)
- [Cloudflare Workers Documentation](https://developers.cloudflare.com/workers/)
- [MCP Inspector Repository](https://github.com/modelcontextprotocol/inspector) 