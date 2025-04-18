import app from "./app";
import { McpAgent } from "agents/mcp";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import OAuthProvider from "@cloudflare/workers-oauth-provider";
import { docsIntegration } from "./integrations";

// Define the environment interface
export interface Env {
  MCP_OBJECT: DurableObjectNamespace;
  OAUTH_KV: KVNamespace;
  GITHUB_CLIENT_ID?: string;
  GITHUB_CLIENT_SECRET?: string;
  DEVDOCS_API_URL?: string; // Optional environment variable for the DevDocs API URL
}

// This is the main MCP Agent class that will be instantiated as a Durable Object
export class DevDocsMCP extends McpAgent {
  server = new McpServer({
    name: "DevDocs MCP Server",
    version: "1.0.0",
    description: "A web development documentation MCP server to help with documentation lookups"
  });

  // Store for documentation cache
  private docsCache: Map<string, any> = new Map();
  
  // Initialize the MCP server with tools
  async init() {
    // Configure the integration
    if (this.env.DEVDOCS_API_URL) {
      // Use the configured API URL from environment variables
      new docsIntegration.constructor(this.env.DEVDOCS_API_URL);
    }

    // Documentation search tool
    this.server.tool("searchDocs", { 
      query: z.string().describe("Search query for documentation"),
      technology: z.string().optional().describe("Specific technology to search (e.g., javascript, react, css)")
    }, async ({ query, technology }) => {
      // Implement documentation search logic
      const results = await docsIntegration.searchDocumentation(query, technology);
      
      return {
        content: [{ 
          type: "text", 
          text: results
        }],
      };
    });

    // Get documentation for a specific topic
    this.server.tool("getDocForTopic", { 
      topic: z.string().describe("Topic to get documentation for"),
      technology: z.string().describe("Technology the topic belongs to (e.g., javascript, react)")
    }, async ({ topic, technology }) => {
      // Fetch documentation for specific topic
      const docContent = await docsIntegration.getDocumentation(topic, technology);
      
      return {
        content: [{ 
          type: "text", 
          text: docContent 
        }],
      };
    });

    // List available documentation categories
    this.server.tool("listTechnologies", {}, 
    async () => {
      const technologies = await docsIntegration.getAvailableTechnologies();
      
      return {
        content: [{ 
          type: "text", 
          text: `Available documentation categories:\n\n${technologies}` 
        }],
      };
    });

    // Get examples for a specific topic/method
    this.server.tool("getExamples", {
      topic: z.string().describe("Topic or method to get examples for"),
      technology: z.string().describe("Technology the topic belongs to")
    }, async ({ topic, technology }) => {
      const examples = await docsIntegration.getCodeExamples(topic, technology);
      
      return {
        content: [{ 
          type: "text", 
          text: examples 
        }],
      };
    });
  }
}

// Export default for Cloudflare Workers
export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    return app.fetch(request, env, ctx);
  }
}; 