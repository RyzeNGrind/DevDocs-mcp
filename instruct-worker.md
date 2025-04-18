# Deploying MCP Servers to Cloudflare Workers

This guide provides step-by-step instructions for deploying a Model Context Protocol (MCP) server to Cloudflare Workers, specifically focusing on migrating from a Node.js-based implementation to a Cloudflare Worker environment.

## What is MCP?

The Model Context Protocol (MCP) is a framework that enables AI models to interact with external tools and services. By deploying an MCP server, you can expose functionality that AI assistants like Claude can use to augment their capabilities.

## Cloudflare Workers vs. Standard Node.js Server

Cloudflare Workers provide several advantages over traditional Node.js servers:

- Edge deployment (close to users worldwide)
- Zero cold starts
- No server maintenance
- Automatic scaling
- Built-in security features

## Prerequisites

- A Cloudflare account
- Node.js installed locally (v18 or newer recommended)
- [Wrangler CLI](https://developers.cloudflare.com/workers/wrangler/) installed (`npm install -g wrangler`)
- Existing MCP server codebase (e.g., `github:ryzengrind/chucknorris`)

## Step 1: Project Setup

```bash
# Login to Cloudflare
wrangler login

# Create a new Worker project or clone your existing MCP server
git clone https://github.com/ryzengrind/chucknorris.git
cd chucknorris

# Initialize Wrangler (if not already configured)
wrangler init
```

## Step 2: Configure wrangler.jsonc

Create or modify the `wrangler.jsonc` configuration file to define your worker:

```jsonc
{
  "$schema": "node_modules/wrangler/config-schema.json",
  "name": "my-mcp-server",
  "main": "src/index.ts", // Or your entry point
  "compatibility_date": "2025-03-10",
  "compatibility_flags": [
    "nodejs_compat"
  ],
  "migrations": [
    {
      "new_sqlite_classes": [
        "MyMCP"
      ],
      "tag": "v1"
    }
  ],
  "durable_objects": {
    "bindings": [
      {
        "class_name": "MyMCP",
        "name": "MCP_OBJECT"
      }
    ]
  },
  // Add your KV namespace for OAuth if needed
  "kv_namespaces": [
    {
      "binding": "OAUTH_KV",
      "id": "<YOUR_KV_NAMESPACE_ID>"
    }
  ],
  "assets": {
    "directory": "./static/",
    "binding": "ASSETS"
  }
}
```

## Step 3: Create the Worker Structure

Your Cloudflare MCP Worker needs these core components:

### 1. Entry Point (src/index.ts)

```typescript
import app from "./app";
import { McpAgent } from "agents/mcp";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import OAuthProvider from "@cloudflare/workers-oauth-provider";

export class MyMCP extends McpAgent {
  server = new McpServer({
    name: "Your MCP Server Name",
    version: "1.0.0",
  });

  async init() {
    // Define your MCP tools here
    this.server.tool("example", { 
      parameter: z.string() 
    }, async ({ parameter }) => ({
      content: [{ type: "text", text: `Processed: ${parameter}` }],
    }));
    
    // Add your existing tools from chucknorris implementation
    // ...
  }
}
```

### 2. Application Handler (src/app.ts)

```typescript
import { Hono } from "hono";
import { serveStatic } from "hono/cloudflare-workers";
import { cors } from "hono/cors";

const app = new Hono();

app.use(cors());
app.get("/", serveStatic({ path: "./index.html" }));

// Handle SSE endpoint for MCP
app.get("/sse", async (c) => {
  const env = c.env as Env;
  const id = env.MCP_OBJECT.newUniqueId();
  const obj = env.MCP_OBJECT.get(id);
  
  return obj.fetch(c.req.raw);
});

export default app;
```

### 3. Static Assets (static/index.html)

Create a basic landing page:

```html
<!DOCTYPE html>
<html>
<head>
  <title>MCP Server</title>
  <style>
    body { font-family: sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
  </style>
</head>
<body>
  <h1>MCP Server</h1>
  <p>Your MCP server is running. Connect to the SSE endpoint at /sse</p>
</body>
</html>
```

## Step 4: Migrate Your Existing MCP Server Code

To migrate your existing chucknorris MCP implementation:

1. Identify the core functionality in your existing server
2. Port your tool definitions to the Cloudflare Worker format
3. Use the same zod schemas for validation
4. Adapt any environment variables and configurations

Example of migrating tools:

```typescript
// In your MyMCP class init() method:

// Assuming your original code had a tool like this:
// server.tool("joke", {}, async () => { ... })

this.server.tool("joke", {}, async () => {
  // Implement your joke fetching logic here
  const response = await fetch("https://api.chucknorris.io/jokes/random");
  const data = await response.json();
  
  return {
    content: [{ type: "text", text: data.value }],
  };
});

// Add other tools from your original implementation...
```

## Step 5: Package.json Dependencies

Update your `package.json` to include necessary dependencies:

```json
{
  "name": "my-mcp-server",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "deploy": "wrangler deploy",
    "dev": "wrangler dev",
    "start": "wrangler dev"
  },
  "dependencies": {
    "@cloudflare/workers-oauth-provider": "^0.0.2",
    "@modelcontextprotocol/sdk": "^1.7.0",
    "agents": "^0.0.53",
    "hono": "^4.7.4",
    "zod": "^3.24.2"
  },
  "devDependencies": {
    "@cloudflare/workers-types": "^4.20250418.0",
    "typescript": "^5.5.2",
    "wrangler": "^4.12.0"
  }
}
```

## Step 6: Development and Testing

Test your worker locally:

```bash
npm run dev
```

This will start a local development server, typically at http://localhost:8787.

You can test your MCP server using the MCP Inspector:

```bash
npx @modelcontextprotocol/inspector
```

Then connect to http://localhost:8787/sse in the inspector.

## Step 7: Deployment

Before deploying, you need to create a KV namespace for OAuth (if you're using authentication):

```bash
npx wrangler kv namespace create OAUTH_KV
```

Copy the ID and add it to your wrangler.jsonc.

Then deploy:

```bash
npm run deploy
```

Your MCP server will be deployed to a workers.dev subdomain (e.g., my-mcp-server.youraccount.workers.dev).

## Step 8: Connect Claude to Your MCP Server

Update the Claude Desktop configuration to use your new Cloudflare Worker:

```json
{
  "mcpServers": {
    "your-server-name": {
      "command": "npx",
      "args": [
        "mcp-remote",
        "https://my-mcp-server.youraccount.workers.dev/sse"
      ]
    }
  }
}
```

## Implementing DevDocs MCP Server

To implement a DevDocs MCP server on Cloudflare Workers, follow the same structure but modify the tools to provide documentation functionality:

```typescript
// In your MyMCP class init() method:

this.server.tool("searchDocs", { 
  query: z.string()
}, async ({ query }) => {
  // Implement documentation search logic
  // This could fetch from a documentation API or KV store
  
  // Sample implementation
  const results = await searchDocumentation(query);
  
  return {
    content: [{ 
      type: "text", 
      text: formatSearchResults(results)
    }],
  };
});

this.server.tool("getDocForTopic", { 
  topic: z.string()
}, async ({ topic }) => {
  // Fetch documentation for specific topic
  const docContent = await getDocumentation(topic);
  
  return {
    content: [{ 
      type: "text", 
      text: docContent 
    }],
  };
});
```

## Advanced Configuration

### Environment Variables

For environment variables, use Cloudflare's secrets:

```bash
npx wrangler secret put API_KEY
```

Then access them in your code:

```typescript
const apiKey = env.API_KEY;
```

### Handling Sessions

For stateful operations, use Durable Objects (already configured in wrangler.jsonc).

### Custom Domains

To use a custom domain:

```bash
npx wrangler domain add mcp-server.yourdomain.com
```

## Troubleshooting

### Worker Size Limits

If your worker exceeds size limits, consider:
- Code splitting
- Removing unnecessary dependencies
- Using KV for large datasets instead of embedding in code

### Debugging

Monitor your worker in the Cloudflare dashboard, which provides logs and error reporting.

For local debugging:
```bash
npx wrangler dev --local
```

## Resources

- [Cloudflare Workers Documentation](https://developers.cloudflare.com/workers/)
- [MCP SDK Documentation](https://modelcontextprotocol.io/docs/)
- [Hono Framework](https://hono.dev/) (lightweight web framework for Workers)