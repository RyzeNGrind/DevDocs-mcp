import { McpAgent } from "agents/mcp";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import OAuthProvider from "@cloudflare/workers-oauth-provider";
import { docsIntegration } from "./integrations.js";
import config from "./config.js";

// Define the environment interface
export interface Env {
  MCP_OBJECT: DurableObjectNamespace;
  OAUTH_KV: KVNamespace;
  GITHUB_CLIENT_ID?: string;
  GITHUB_CLIENT_SECRET?: string;
  DEVDOCS_API_URL?: string; // Optional environment variable for the DevDocs API URL
}

// DocState interface for type safety in state management
interface DocState {
  navigationHistory: Array<{
    topic: string;
    technology: string;
    timestamp: string;
  }>;
  lastQuery?: string;
  searchResults?: any[];
  currentTechnology?: string;
  currentTopic?: string;
  requestCount: number;
  cacheEntries: Record<string, {
    data: any;
    timestamp: number;
    expiresAt: number;
  }>;
}

// Initial state for the MCP Agent
const initialDocState: DocState = {
  navigationHistory: [],
  requestCount: 0,
  cacheEntries: {}
};

// Type for tool responses
interface ToolResponse {
  content: Array<{
    type: "text";
    text: string;
  }>;
  [key: string]: unknown;
}

// This is the main MCP Agent class that will be instantiated as a Durable Object
export class DevDocsMCP extends McpAgent {
  server = new McpServer({
    name: "DevDocs MCP Server",
    version: "1.0.0",
    description: "A web development documentation MCP server to help with documentation lookups"
  });

  // Store our custom state data
  private docState: DocState = { ...initialDocState };
  
  // Cache management for free tier optimization
  private cacheTimeout = 30 * 60 * 1000; // 30 minutes
  private maxCacheEntries = 50; // Limit cache size for free tier
  private requestRateLimit = 50; // Rate limit per minute for free tier
  private lastMinuteRequests: number[] = [];
  
  // Type definition for the environment with proper typings
  env: Env = {} as Env;
  
  // Initialize the MCP server with tools
  async init() {
    // Load state first
    const state = await this.onStateUpdate({ docState: null });
    if (state && state.docState) {
      this.docState = {
        ...initialDocState,
        ...state.docState
      };
    }
    
    // Configure the integration
    if (this.env && this.env.DEVDOCS_API_URL) {
      docsIntegration.setApiUrl(this.env.DEVDOCS_API_URL);
    }

    // ---------- PATTERN: ROUTING ----------
    // Documentation search tool with query routing
    this.server.tool("searchDocs", 
      "Search for documentation across technologies",
      { 
        query: z.string().describe("Search query for documentation"),
        technology: z.string().optional().describe("Specific technology to search (e.g., javascript, react, css)")
      }, 
      async (params): Promise<ToolResponse> => {
        const { query, technology } = params;
        await this.checkRateLimit();
        
        // Update state for history tracking
        const timestamp = new Date().toISOString();
        this.updateState({
          lastQuery: query,
          requestCount: this.docState.requestCount + 1
        });
        
        // Route query to appropriate handler
        if (technology) {
          // Technology-specific search
          return await this.handleTechnologySearch(query, technology, timestamp);
        } else {
          // General search across all technologies
          return await this.handleGeneralSearch(query, timestamp);
        }
      }
    );

    // ---------- PATTERN: STATE MANAGEMENT ----------
    // Get documentation for a specific topic with state tracking
    this.server.tool("getDocForTopic", 
      "Get detailed documentation for a specific topic",
      { 
        topic: z.string().describe("Topic to get documentation for"),
        technology: z.string().describe("Technology the topic belongs to (e.g., javascript, react)")
      },
      async (params) => {
        const { topic, technology } = params;
        await this.checkRateLimit();
        
        // Check cache first (free tier optimization)
        const cacheKey = `doc:${technology}:${topic}`;
        const cachedResult = this.getCachedData(cacheKey);
        
        if (cachedResult) {
          return {
            content: [{ 
              type: "text", 
              text: cachedResult 
            }],
          };
        }
        
        // Fetch documentation if not cached
        try {
          const docContent = await docsIntegration.getDocumentation(topic, technology);
          
          // Track in navigation history
          const timestamp = new Date().toISOString();
          const updatedHistory = [
            ...this.docState.navigationHistory,
            { topic, technology, timestamp }
          ].slice(-10); // Keep last 10 items for memory optimization
          
          // Update state
          this.updateState({
            navigationHistory: updatedHistory,
            currentTechnology: technology,
            currentTopic: topic,
            requestCount: this.docState.requestCount + 1
          });
          
          // Cache result
          this.setCachedData(cacheKey, docContent);
          
          return {
            content: [{ 
              type: "text", 
              text: docContent 
            }],
          };
        } catch (error) {
          console.error(`Error getting documentation for ${topic} in ${technology}:`, error);
          
          // Return fallback content
          return {
            content: [{ 
              type: "text", 
              text: `Documentation for ${topic} in ${technology} could not be retrieved. Please try again later.` 
            }],
          };
        }
      }
    );

    // List available documentation categories
    this.server.tool("listTechnologies", 
      "List all available documentation categories",
      {}, 
      async () => {
        await this.checkRateLimit();
        
        // Check cache for technologies list
        const cacheKey = "technologies:list";
        const cachedResult = this.getCachedData(cacheKey);
        
        if (cachedResult) {
          return {
            content: [{ 
              type: "text", 
              text: cachedResult 
            }],
          };
        }
        
        // Fetch technologies if not cached
        try {
          const technologies = await docsIntegration.getAvailableTechnologies();
          
          // Update request count
          this.updateState({
            requestCount: this.docState.requestCount + 1
          });
          
          // Cache result
          this.setCachedData(cacheKey, technologies);
          
          return {
            content: [{ 
              type: "text", 
              text: technologies 
            }],
          };
        } catch (error) {
          console.error("Error getting technologies:", error);
          
          // Return fallback content
          return {
            content: [{ 
              type: "text", 
              text: "Available documentation categories could not be retrieved. Please try again later." 
            }],
          };
        }
      }
    );

    // ---------- PATTERN: PROMPT CHAINING ----------
    // Get examples for a specific topic/method
    this.server.tool("getExamples",
      "Get code examples for a specific topic or method",
      {
        topic: z.string().describe("Topic or method to get examples for"),
        technology: z.string().describe("Technology the topic belongs to")
      }, 
      async (params) => {
        const { topic, technology } = params;
        await this.checkRateLimit();
        
        // Check if we need previous context from state
        let effectiveTopic = topic;
        let effectiveTechnology = technology;
        
        // If topic is "current" or similar words, use the last visited topic
        if (["current", "this", "same"].includes(topic.toLowerCase()) && this.docState.currentTopic) {
          effectiveTopic = this.docState.currentTopic;
          console.log(`Using current topic: ${effectiveTopic}`);
        }
        
        // If technology is "current" or similar words, use the last visited technology
        if (["current", "this", "same"].includes(technology.toLowerCase()) && this.docState.currentTechnology) {
          effectiveTechnology = this.docState.currentTechnology;
          console.log(`Using current technology: ${effectiveTechnology}`);
        }
        
        // Check cache
        const cacheKey = `examples:${effectiveTechnology}:${effectiveTopic}`;
        const cachedResult = this.getCachedData(cacheKey);
        
        if (cachedResult) {
          return {
            content: [{ 
              type: "text", 
              text: cachedResult 
            }],
          };
        }
        
        try {
          const examples = await docsIntegration.getCodeExamples(effectiveTopic, effectiveTechnology);
          
          // Update state
          this.updateState({
            requestCount: this.docState.requestCount + 1
          });
          
          // Cache result
          this.setCachedData(cacheKey, examples);
          
          return {
            content: [{ 
              type: "text", 
              text: examples 
            }],
          };
        } catch (error) {
          console.error(`Error getting examples for ${effectiveTopic} in ${effectiveTechnology}:`, error);
          
          // Return fallback content
          return {
            content: [{ 
              type: "text", 
              text: `Examples for ${effectiveTopic} in ${effectiveTechnology} could not be retrieved. Please try again later.` 
            }],
          };
        }
      }
    );

    // Get navigation history
    this.server.tool("getNavigationHistory",
      "Get the user's documentation navigation history",
      {}, 
      async () => {
        // Return navigation history
        const history = this.docState.navigationHistory;
        
        let historyText = "Navigation History:\n\n";
        
        if (history.length === 0) {
          historyText += "No navigation history found.";
        } else {
          historyText += history.map((item, index) => {
            const date = new Date(item.timestamp).toLocaleString();
            return `${index + 1}. Topic: ${item.topic}, Technology: ${item.technology}, Time: ${date}`;
          }).join("\n");
        }
        
        return {
          content: [{ 
            type: "text", 
            text: historyText 
          }],
        };
      }
    );
  }
  
  // ---------- FREE TIER OPTIMIZATIONS ----------
  
  // Rate limiting for free tier
  private async checkRateLimit() {
    const now = Date.now();
    
    // Remove requests older than 1 minute
    this.lastMinuteRequests = this.lastMinuteRequests.filter(time => now - time < 60000);
    
    // Check if we've exceeded the rate limit
    if (this.lastMinuteRequests.length >= this.requestRateLimit) {
      throw new Error(`Rate limit exceeded. Please try again in a minute. (${this.requestRateLimit} requests per minute maximum)`);
    }
    
    // Add current request
    this.lastMinuteRequests.push(now);
  }
  
  // Cached data helpers
  private getCachedData(key: string): string | null {
    const cacheEntry = this.docState.cacheEntries[key];
    
    if (cacheEntry && cacheEntry.expiresAt > Date.now()) {
      return cacheEntry.data;
    }
    
    return null;
  }
  
  private setCachedData(key: string, data: string): void {
    // Create new cache entry
    const now = Date.now();
    const cacheEntries = { ...this.docState.cacheEntries };
    
    // Add new entry
    cacheEntries[key] = {
      data,
      timestamp: now,
      expiresAt: now + this.cacheTimeout
    };
    
    // If we have too many entries, remove the oldest
    const keys = Object.keys(cacheEntries);
    if (keys.length > this.maxCacheEntries) {
      // Find oldest entry
      let oldestKey = keys[0];
      let oldestTime = cacheEntries[oldestKey].timestamp;
      
      for (const entryKey of keys) {
        if (cacheEntries[entryKey].timestamp < oldestTime) {
          oldestKey = entryKey;
          oldestTime = cacheEntries[entryKey].timestamp;
        }
      }
      
      // Remove oldest entry
      delete cacheEntries[oldestKey];
    }
    
    // Update state
    this.updateState({ cacheEntries });
  }
  
  // ---------- ROUTING HANDLERS ----------
  
  // Handle technology-specific search
  private async handleTechnologySearch(query: string, technology: string, timestamp: string): Promise<ToolResponse> {
    try {
      // Fetch technology-specific results
      const results = await docsIntegration.searchDocumentation(query, technology);
      
      // Update navigation history
      const updatedHistory = [
        ...this.docState.navigationHistory,
        { topic: query, technology, timestamp }
      ].slice(-10); // Keep last 10 items only
      
      // Update state
      this.updateState({
        navigationHistory: updatedHistory,
        currentTechnology: technology,
        searchResults: [results]
      });
      
      return {
        content: [{ 
          type: "text", 
          text: results 
        }],
      };
    } catch (error) {
      console.error(`Error in technology search for "${query}" in ${technology}:`, error);
      return {
        content: [{ 
          type: "text", 
          text: `Error searching for "${query}" in ${technology}. Please try again later.` 
        }],
      };
    }
  }
  
  // Handle general search across all technologies
  private async handleGeneralSearch(query: string, timestamp: string): Promise<ToolResponse> {
    try {
      // Fetch general results
      const results = await docsIntegration.searchDocumentation(query);
      
      // Update navigation history
      const updatedHistory = [
        ...this.docState.navigationHistory,
        { topic: query, technology: "general", timestamp }
      ].slice(-10);
      
      // Update state
      this.updateState({
        navigationHistory: updatedHistory,
        currentTechnology: undefined,
        searchResults: [results]
      });
      
      return {
        content: [{ 
          type: "text", 
          text: results 
        }],
      };
    } catch (error) {
      console.error(`Error in general search for "${query}":`, error);
      return {
        content: [{ 
          type: "text", 
          text: `Error searching for "${query}". Please try again later.` 
        }],
      };
    }
  }
  
  // State management helper
  private updateState(updates: Partial<DocState>) {
    this.docState = {
      ...this.docState,
      ...updates
    };
    
    // Persist state updates
    this.setState({ docState: this.docState });
  }
  
  // Override onStateUpdate to sync our custom state
  async onStateUpdate(state: Record<string, unknown>) {
    if (state && state.docState) {
      this.docState = state.docState as DocState;
    }
    return state;
  }
}

// Export default for Cloudflare Workers
export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    // Extract URL to check for SSE endpoint
    const url = new URL(request.url);
    
    if (url.pathname === "/sse") {
      // Get a unique ID for this session
      const id = env.MCP_OBJECT.newUniqueId();
      const obj = env.MCP_OBJECT.get(id);
      
      // Forward the request to the Durable Object
      return await obj.fetch(request);
    }
    
    // For other routes, delegate to the app
    return new Response("Not found", { status: 404 });
  }
}; 