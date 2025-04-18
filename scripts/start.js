#!/usr/bin/env node

/**
 * DevDocs Explorer Startup Script
 * 
 * This script handles the startup of all DevDocs Explorer components:
 * - MCP Server (Cloudflare Workers)
 * - Backend Server (FastAPI)
 * 
 * It ensures proper environment variable loading and service coordination.
 */

const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const dotenv = require('dotenv');

// Load environment variables
const envPath = path.resolve(__dirname, '..', '.env');
if (fs.existsSync(envPath)) {
  console.log('Loading environment variables from .env file');
  dotenv.config({ path: envPath });
} else {
  console.log('No .env file found, using default environment variables');
}

// Default ports (can be overridden by environment variables)
const MCP_PORT = process.env.MCP_PORT || 8787;
const BACKEND_PORT = process.env.BACKEND_PORT || 24125;

console.log(`Starting DevDocs Explorer services...`);
console.log(`- MCP Server port: ${MCP_PORT}`);
console.log(`- Backend Server port: ${BACKEND_PORT}`);

// Function to start a service
function startService(name, command, args, options = {}) {
  console.log(`Starting ${name}...`);
  
  const service = spawn(command, args, {
    stdio: 'inherit',
    shell: true,
    ...options
  });
  
  service.on('error', (error) => {
    console.error(`Error starting ${name}: ${error.message}`);
  });
  
  service.on('close', (code) => {
    if (code !== 0) {
      console.error(`${name} process exited with code ${code}`);
    }
  });
  
  return service;
}

// Start the MCP server
const mcpServer = startService(
  'MCP Server',
  'npm',
  ['run', 'dev'],
  { 
    cwd: path.resolve(__dirname, '..', 'devdocs-mcp'),
    env: {
      ...process.env,
      PORT: MCP_PORT
    }
  }
);

// Start the backend server
const backendServer = startService(
  'Backend Server',
  'python',
  ['-m', 'app.main'],
  { 
    cwd: path.resolve(__dirname, '..', 'backend'),
    env: {
      ...process.env,
      BACKEND_PORT: BACKEND_PORT,
      MCP_PORT: MCP_PORT
    }
  }
);

// Handle process termination
process.on('SIGINT', () => {
  console.log('Shutting down services...');
  mcpServer.kill();
  backendServer.kill();
  process.exit(0);
});

console.log('All services started successfully. Press Ctrl+C to stop.'); 