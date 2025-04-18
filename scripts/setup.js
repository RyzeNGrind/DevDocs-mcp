#!/usr/bin/env node

/**
 * DevDocs Explorer Setup Script
 * 
 * This script handles the setup of all DevDocs Explorer components:
 * - MCP Server (Cloudflare Workers)
 * - Backend Server (FastAPI)
 * 
 * It ensures proper dependency installation and directory structure.
 */

const { spawn, execSync } = require('child_process');
const path = require('path');
const fs = require('fs-extra');
const os = require('os');

// Root directory
const rootDir = path.resolve(__dirname, '..');
const mcpDir = path.join(rootDir, 'devdocs-mcp');
const backendDir = path.join(rootDir, 'backend');

// Utility to run a command and log output
function runCommand(command, cwd = rootDir) {
  try {
    console.log(`Running: ${command} in ${cwd}`);
    execSync(command, { 
      cwd, 
      stdio: 'inherit',
      shell: true
    });
    return true;
  } catch (error) {
    console.error(`Error executing command: ${command}`);
    console.error(error.message);
    return false;
  }
}

// Create required directories
console.log('Creating required directories...');
fs.ensureDirSync(path.join(rootDir, 'storage', 'markdown'));
fs.ensureDirSync(path.join(rootDir, 'storage', 'html'));
fs.ensureDirSync(path.join(rootDir, 'logs'));
fs.ensureDirSync(path.join(rootDir, 'scripts'));

// Set up root .env file if it doesn't exist
const envPath = path.join(rootDir, '.env');
if (!fs.existsSync(envPath)) {
  console.log('Creating default .env file...');
  const envContent = `# DevDocs Explorer Environment Configuration
# MCP Server Configuration
MCP_PORT=8787
GITHUB_CLIENT_ID=
GITHUB_CLIENT_SECRET=

# Backend Server Configuration
BACKEND_PORT=24125
BACKEND_HOST=0.0.0.0
CRAWL4AI_URL=http://crawl4ai:11235
CRAWL4AI_API_TOKEN=devdocs-demo-key

# Storage Configuration
STORAGE_PATH=storage
MARKDOWN_DIR=storage/markdown
HTML_DIR=storage/html

# CORS Configuration
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:3001,http://127.0.0.1:3000,http://127.0.0.1:3001,http://frontend:3001
`;
  fs.writeFileSync(envPath, envContent);
  console.log('Created default .env file');
}

// Set up MCP server
console.log('Setting up MCP server...');
if (fs.existsSync(mcpDir)) {
  // Install dependencies for MCP server
  runCommand('npm install', mcpDir);
  
  // Copy .env variables to .dev.vars for Wrangler
  if (fs.existsSync(envPath)) {
    console.log('Copying environment variables to .dev.vars...');
    const dotenvContent = fs.readFileSync(envPath, 'utf8');
    const relevantVars = dotenvContent.split('\n')
      .filter(line => line.startsWith('GITHUB_') || line.startsWith('MCP_'))
      .join('\n');
    
    fs.writeFileSync(path.join(mcpDir, '.dev.vars'), relevantVars);
  }
} else {
  console.error('MCP server directory not found. Please check the repository structure.');
}

// Set up Backend
console.log('Setting up Backend server...');
if (fs.existsSync(backendDir)) {
  // Create Python virtual environment if it doesn't exist
  const venvPath = path.join(backendDir, 'venv');
  if (!fs.existsSync(venvPath)) {
    console.log('Creating Python virtual environment...');
    
    // Check Python version
    const pythonCommand = os.platform() === 'win32' ? 'python' : 'python3';
    runCommand(`${pythonCommand} -m venv venv`, backendDir);
  }
  
  // Install Python dependencies
  console.log('Installing Python dependencies...');
  const pipCommand = os.platform() === 'win32' ? 
    'venv\\Scripts\\pip.exe' : 
    './venv/bin/pip';
  
  runCommand(`${pipCommand} install -r requirements.txt`, backendDir);
} else {
  console.error('Backend directory not found. Please check the repository structure.');
}

// Create clean directories and symlinks
console.log('Creating shared storage directories...');

// Ensure mcp storage points to the root storage
const mcpStorageDir = path.join(mcpDir, 'storage');
if (fs.existsSync(mcpStorageDir)) {
  fs.removeSync(mcpStorageDir);
}

// Try to create symlinks for better file sharing
try {
  fs.symlinkSync(
    path.join(rootDir, 'storage'), 
    mcpStorageDir,
    'dir'
  );
  console.log('Created symlink for MCP storage');
} catch (error) {
  // Fallback to copying if symlinks fail
  console.log('Symlink creation failed, copying storage directory instead');
  fs.copySync(path.join(rootDir, 'storage'), mcpStorageDir);
}

console.log('Setup completed successfully!');
console.log('To start the services, run: npm start'); 