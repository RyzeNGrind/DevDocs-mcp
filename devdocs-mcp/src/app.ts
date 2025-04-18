import { Hono } from "hono";
import { serveStatic } from "hono/cloudflare-workers";
import { cors } from "hono/cors";
import type { Env } from "./index";
import OAuthProvider from "@cloudflare/workers-oauth-provider";

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

// Export the app
export default app;