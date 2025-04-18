/**
 * DevDocs MCP Server Configuration
 * 
 * This file centralizes all configuration settings and environment variables.
 * It ensures that ports and other variables are dynamic rather than hardcoded.
 */

// Environment variables with defaults
export const config = {
  // Server configuration
  server: {
    port: parseInt(process.env.PORT || '8787'),
    dev_mode: process.env.NODE_ENV !== 'production',
  },
  
  // API configuration
  api: {
    // Backend service connection
    backend: {
      url: process.env.BACKEND_API_URL || 'http://localhost:24125',
      timeout: parseInt(process.env.API_TIMEOUT || '30000'),
    },
    
    // Documentation service
    docs: {
      url: process.env.DOCS_API_URL || process.env.BACKEND_API_URL || 'http://localhost:24125',
    },
    
    // Crawler service
    crawler: {
      url: process.env.CRAWL4AI_URL || 'http://localhost:11235',
      token: process.env.CRAWL4AI_API_TOKEN || 'devdocs-demo-key',
    }
  },
  
  // Authentication
  auth: {
    github: {
      client_id: process.env.GITHUB_CLIENT_ID,
      client_secret: process.env.GITHUB_CLIENT_SECRET,
    },
  },
  
  // Storage paths (for local dev environment)
  storage: {
    markdown_dir: process.env.MARKDOWN_DIR || './storage/markdown',
    html_dir: process.env.HTML_DIR || './storage/html',
  },
  
  // Debug mode
  debug: process.env.DEBUG === 'true',
};

// Helper function to validate required configuration
export function validateConfig() {
  const requiredVars = [
    // Add required variables here when needed
    // Example: ['auth.github.client_id', 'API keys required for OAuth']
  ];
  
  const errors = [];
  
  for (const [path, message] of requiredVars) {
    const keys = path.split('.');
    let value = config;
    
    for (const key of keys) {
      value = value[key];
      if (value === undefined) break;
    }
    
    if (!value) {
      errors.push(`Missing required config: ${path} - ${message}`);
    }
  }
  
  if (errors.length > 0) {
    // In development, log warnings but don't fail
    if (config.server.dev_mode) {
      console.warn('⚠️ Configuration warnings:');
      errors.forEach(error => console.warn(`  - ${error}`));
    } else {
      // In production, throw error if required configs are missing
      throw new Error(`Configuration errors: ${errors.join(', ')}`);
    }
  }
  
  return errors.length === 0;
}

export default config; 