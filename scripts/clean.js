#!/usr/bin/env node

/**
 * DevDocs Explorer Cleanup Script
 * 
 * This script cleans up redundant files and ensures proper organization
 * of the codebase. It addresses issues with duplicated configurations
 * and storage directories.
 */

const fs = require('fs-extra');
const path = require('path');

// Root directory
const rootDir = path.resolve(__dirname, '..');
const mcpDir = path.join(rootDir, 'devdocs-mcp');
const backendDir = path.join(rootDir, 'backend');

console.log('Starting cleanup process...');

// Create a backup directory
const backupDir = path.join(rootDir, 'backups', `backup-${Date.now()}`);
fs.ensureDirSync(backupDir);
console.log(`Created backup directory: ${backupDir}`);

// Function to backup and remove a file or directory
function backupAndRemove(filePath) {
  if (!fs.existsSync(filePath)) return;
  
  const relativePath = path.relative(rootDir, filePath);
  const backupPath = path.join(backupDir, relativePath);
  
  // Ensure backup parent directory exists
  fs.ensureDirSync(path.dirname(backupPath));
  
  // Copy to backup
  if (fs.statSync(filePath).isDirectory()) {
    fs.copySync(filePath, backupPath);
    console.log(`Backed up directory: ${relativePath}`);
  } else {
    fs.copySync(filePath, backupPath);
    console.log(`Backed up file: ${relativePath}`);
  }
  
  // Remove original
  fs.removeSync(filePath);
  console.log(`Removed: ${relativePath}`);
}

// Clean up redundant storage directories in component folders
[
  path.join(mcpDir, 'storage'),
  path.join(backendDir, 'storage')
].forEach(dir => {
  // Only backup and remove if it's not a symlink
  if (fs.existsSync(dir) && !fs.lstatSync(dir).isSymbolicLink()) {
    // Move any unique content to the root storage
    const rootStorage = path.join(rootDir, 'storage');
    fs.ensureDirSync(rootStorage);
    
    try {
      // Copy contents instead of the directory itself
      if (fs.existsSync(path.join(dir, 'markdown'))) {
        fs.copySync(path.join(dir, 'markdown'), path.join(rootStorage, 'markdown'), { overwrite: false });
      }
      if (fs.existsSync(path.join(dir, 'html'))) {
        fs.copySync(path.join(dir, 'html'), path.join(rootStorage, 'html'), { overwrite: false });
      }
      
      // Now back up and remove the directory
      backupAndRemove(dir);
      
      // Create symlink to root storage
      fs.symlinkSync(
        path.join(rootDir, 'storage'), 
        dir,
        'dir'
      );
      console.log(`Created symlink from ${dir} to root storage`);
    } catch (error) {
      console.error(`Error processing ${dir}: ${error.message}`);
    }
  }
});

// Centralize configuration files
// Create symlinks for configuration files
try {
  // Ensure .env exists at root
  const rootEnvPath = path.join(rootDir, '.env');
  if (!fs.existsSync(rootEnvPath)) {
    // Create default .env if needed
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
    fs.writeFileSync(rootEnvPath, envContent);
  }
  
  // Copy appropriate variables to component config files
  const envContent = fs.readFileSync(rootEnvPath, 'utf8');
  
  // Update MCP .dev.vars
  const mcpVars = envContent.split('\n')
    .filter(line => line.startsWith('GITHUB_') || line.startsWith('MCP_'))
    .join('\n');
  fs.writeFileSync(path.join(mcpDir, '.dev.vars'), mcpVars);
  console.log('Updated MCP .dev.vars with environment variables');
  
} catch (error) {
  console.error(`Error centralizing configuration: ${error.message}`);
}

// Clean up any .DS_Store or other temporary files
const filesToRemove = [
  '.DS_Store',
  'Thumbs.db',
  '.vscode/settings.json.bak',
  'node_modules/.cache'
];

filesToRemove.forEach(filePattern => {
  const files = [];
  
  function findFiles(dir, pattern) {
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);
      if (entry.isDirectory() && entry.name !== 'node_modules' && entry.name !== 'venv') {
        findFiles(fullPath, pattern);
      } else if (entry.name === pattern) {
        files.push(fullPath);
      }
    }
  }
  
  findFiles(rootDir, filePattern);
  
  files.forEach(file => {
    try {
      fs.removeSync(file);
      console.log(`Removed: ${path.relative(rootDir, file)}`);
    } catch (error) {
      console.error(`Error removing ${file}: ${error.message}`);
    }
  });
});

console.log('Cleanup completed successfully!'); 