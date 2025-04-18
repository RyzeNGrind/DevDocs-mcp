# DevDocs MCP Server on NixOS

This guide provides instructions for setting up and running the DevDocs MCP server on NixOS or NixOS-WSL.

## Prerequisites

- NixOS or NixOS-WSL
- Git (usually available by default on NixOS)
- A Cloudflare account

## Setup Options

### Option 1: Using the Nix Shell (Recommended)

1. Run the provided script to enter a Nix shell with all required dependencies:

```bash
./nix-setup.sh
```

2. Once in the Nix shell, navigate to the project directory and install dependencies:

```bash
cd devdocs-mcp
npm install
```

3. Deploy to Cloudflare Workers:

```bash
npx wrangler deploy
```

### Option 2: Using Nix Flakes (For Nix Flake Users)

If you have flakes enabled in your NixOS configuration:

1. Enter a development shell using flakes:

```bash
nix develop
```

2. The shell will provide all necessary dependencies. Then:

```bash
cd devdocs-mcp
npm install
npx wrangler deploy
```

### Option 3: Manual Configuration

If you prefer to set up your environment manually:

1. Install required packages in your `configuration.nix`:

```nix
environment.systemPackages = with pkgs; [
  nodejs_20
  nodePackages.wrangler
  nodePackages.typescript
];
```

2. Run `sudo nixos-rebuild switch` to apply the configuration.

3. Follow the standard deployment instructions in the main README.

## Troubleshooting

### KV Namespace Issues

If you encounter issues with the KV namespace, you can list existing namespaces and update the configuration manually:

```bash
npx wrangler kv namespace list
```

Then update the `id` field in `wrangler.jsonc`:

```jsonc
"kv_namespaces": [
  {
    "binding": "OAUTH_KV",
    "id": "your-namespace-id-here"
  }
]
```

### Permissions Issues

On NixOS, npm cannot install packages globally by default. Always use local installations or Nix development shells.

## Workers URL

Your MCP server will be deployed to:
`https://devdocs-mcp.vidurshan-sribala.workers.dev/`

## MCP Client Configuration

### For Claude:

Save this to `claude_mcp_settings.json`:

```json
{
  "mcpServers": {
    "devdocs": {
      "command": "npx",
      "args": [
        "mcp-remote",
        "https://devdocs-mcp.vidurshan-sribala.workers.dev/sse"
      ],
      "env": {}
    }
  }
}
```

### For Cursor:

Configure your MCP server in Cursor:

- **Name**: `devdocs`
- **Type**: `command`
- **Command**: `npx mcp-remote https://devdocs-mcp.vidurshan-sribala.workers.dev/sse`