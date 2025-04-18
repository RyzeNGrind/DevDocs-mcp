# DevDocs MCP Server

A Model Context Protocol (MCP) server for web development documentation, deployed to Cloudflare Workers. This server integrates with your existing DevDocs Explorer and makes its functionality available to AI assistants like Claude and other MCP clients.

## Features

- **Documentation Search**: Search across web development technologies
- **Topic Documentation**: Get detailed documentation for specific topics
- **Technology Listings**: List all available documentation categories
- **Code Examples**: Get examples for specific methods and topics
- **OAuth Authentication**: Support for GitHub authentication

## Prerequisites

- A Cloudflare account
- Node.js installed locally (v18 or newer recommended)
- [Wrangler CLI](https://developers.cloudflare.com/workers/wrangler/) installed (`npm install -g wrangler`)

## Setup and Deployment

### 1. Clone and Install Dependencies

```bash
git clone https://github.com/yourusername/devdocs-mcp.git
cd devdocs-mcp
npm install
```

### 2. Configure OAuth (Optional but Recommended)

Create a GitHub OAuth App at https://github.com/settings/developers:

- **Application name**: DevDocs MCP Server
- **Homepage URL**: Your worker URL (e.g., https://devdocs-mcp.your-account.workers.dev)
- **Authorization callback URL**: Your worker callback URL (e.g., https://devdocs-mcp.your-account.workers.dev/callback)

Set the Client ID and Secret as secrets:

```bash
npx wrangler secret put GITHUB_CLIENT_ID
npx wrangler secret put GITHUB_CLIENT_SECRET
```

### 3. Create a KV Namespace for OAuth

```bash
npx wrangler kv:namespace create OAUTH_KV
```

Update your wrangler.jsonc with the KV namespace ID.

### 4. Integrate with DevDocs Data

The server is currently set up with mock responses. To integrate with your actual DevDocs data, modify the following methods in `src/index.ts`:

- `searchDocumentation`
- `getDocumentation`
- `getAvailableTechnologies`
- `getCodeExamples`

You can either:
- Connect to your existing DevDocs backend APIs
- Store documentation data in KV storage
- Implement direct access to your data sources

### 5. Deploy to Cloudflare

```bash
npm run deploy
```

Your MCP server will be deployed to a workers.dev subdomain (e.g., devdocs-mcp.your-account.workers.dev).

## Connecting to the MCP Server

### Claude Desktop

Update the Claude Desktop configuration:

```json
{
  "mcpServers": {
    "devdocs": {
      "command": "npx",
      "args": [
        "mcp-remote",
        "https://devdocs-mcp.your-account.workers.dev/sse"
      ]
    }
  }
}
```

### Cursor

In Cursor, create an MCP server entry with:

- **Type**: `command`
- **Command**: `npx mcp-remote https://devdocs-mcp.your-account.workers.dev/sse`

## Development

For local development:

```bash
npm run dev
```

This will start a local development server, typically at http://localhost:8787.

You can test your MCP server using the MCP Inspector:

```bash
npx @modelcontextprotocol/inspector
```

Then connect to http://localhost:8787/sse in the inspector.

## License

[MIT License](LICENSE)

## Acknowledgements

This project builds on the following technologies:
- [Model Context Protocol](https://modelcontextprotocol.io/)
- [Cloudflare Workers](https://workers.cloudflare.com/)
- [DevDocs Explorer](https://github.com/cyberagiinc/DevDocs)