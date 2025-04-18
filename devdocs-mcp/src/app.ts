import { Hono } from "hono";
import { serveStatic } from "hono/cloudflare-workers";
import { cors } from "hono/cors";
import type { Env } from "./index";
import OAuthProvider from "@cloudflare/workers-oauth-provider";
import config from "./config.js";

// Create the Hono app
const app = new Hono<{ Bindings: Env }>();

// Enable CORS for all routes
app.use(cors({
  origin: "*",
  allowMethods: ["GET", "POST", "OPTIONS"],
  allowHeaders: ["Content-Type", "Authorization"]
}));

// Home page route
app.get("/", serveStatic({ path: "./index.html" }));

// Status route for health checks
app.get("/status", (c) => {
  return c.json({
    status: "ok",
    service: "DevDocs MCP Server",
    version: "1.0.0",
    timestamp: new Date().toISOString()
  });
});

// OAuth callback route
app.get("/callback", async (c) => {
  const env = c.env;
  const url = new URL(c.req.url);
  
  // Create an OAuth provider instance
  if (!env.GITHUB_CLIENT_ID || !env.GITHUB_CLIENT_SECRET) {
    return c.json({ error: "OAuth configuration missing" }, 500);
  }
  
  const provider = new OAuthProvider({
    clientId: env.GITHUB_CLIENT_ID,
    clientSecret: env.GITHUB_CLIENT_SECRET,
    authorizationUrl: "https://github.com/login/oauth/authorize",
    tokenUrl: "https://github.com/login/oauth/access_token",
    // The KV namespace for storing tokens
    storage: env.OAUTH_KV
  });
  
  try {
    // Handle the OAuth callback
    const response = await provider.handleCallback(url);
    return response;
  } catch (error) {
    console.error("OAuth callback error:", error);
    return c.json({ error: "Authentication failed" }, 500);
  }
});

// SSE endpoint for MCP communication
app.get("/sse", async (c) => {
  const env = c.env;
  const id = env.MCP_OBJECT.newUniqueId();
  const obj = env.MCP_OBJECT.get(id);
  
  // Forward the request to the Durable Object
  return obj.fetch(c.req.raw);
});

// MCP endpoint for editor integration
app.post("/mcp", async (c) => {
  try {
    const body = await c.req.json();
    const query = body.query;
    const source = body.source || "unknown";
    const context = body.context || {};
    
    // Log the request (for debugging)
    if (config.debug) {
      console.log(`MCP Request from ${source}: ${query}`);
    }
    
    // This is where you would normally query your document database
    // Connect to the backend API if configured
    let response;
    if (config.api.backend.url) {
      try {
        // Try to fetch from the backend
        const backendResponse = await fetch(`${config.api.backend.url}/api/search?q=${encodeURIComponent(query)}`, {
          method: 'GET',
          headers: {
            'Content-Type': 'application/json'
          },
          signal: AbortSignal.timeout(config.api.backend.timeout)
        });
        
        if (backendResponse.ok) {
          const data = await backendResponse.json();
          response = {
            response: data.content || `Results for "${query}":\n\n${JSON.stringify(data, null, 2)}`,
            query: query,
            source: source,
            timestamp: new Date().toISOString(),
            metadata: {
              documentCount: data.count || 1,
              searchTime: data.time || "10ms",
              source: "devdocs-backend"
            }
          };
        } else {
          throw new Error(`Backend responded with status ${backendResponse.status}`);
        }
      } catch (error) {
        console.error("Backend API error:", error);
        // Fallback to default response
        response = getFallbackResponse(query, source);
      }
    } else {
      // Use default response if no backend is configured
      response = getFallbackResponse(query, source);
    }
    
    return c.json(response);
  } catch (error) {
    console.error("MCP error:", error);
    return c.json({ error: "Failed to process MCP request" }, 500);
  }
});

// Helper function for fallback response
function getFallbackResponse(query, source) {
  return {
    response: `Here's information about "${query}" from DevDocs.\n\n` +
              `This is a simulated response from the MCP server.\n\n` +
              `In a real implementation, this would search through your documentation ` +
              `and return relevant information based on the query.`,
    query: query,
    source: source,
    timestamp: new Date().toISOString(),
    metadata: {
      documentCount: 5,
      searchTime: "20ms",
      source: "devdocs-mcp"
    }
  };
}

// Export the app
export default app;