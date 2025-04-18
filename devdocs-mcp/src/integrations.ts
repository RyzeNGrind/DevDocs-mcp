/**
 * DevDocs MCP Server Integration Helpers
 * 
 * This file contains helper functions to integrate the MCP server with your
 * existing DevDocs Explorer data. You'll need to customize these functions
 * to access your documentation sources.
 */

// Types for documentation data
export interface DocSearchResult {
  title: string;
  path: string;
  description: string;
  content: string;
  relevance: number;
}

export interface TechnologyInfo {
  name: string;
  version?: string;
  description?: string;
  url?: string;
}

export interface CodeExample {
  title: string;
  code: string;
  description?: string;
}

// Default Dev API URL (update this to your actual backend URL)
const DEFAULT_API_URL = 'http://localhost:24125';

/**
 * Configure the API URL for the DevDocs backend
 */
export class DocsIntegration {
  private apiUrl: string;

  constructor(apiUrl: string = DEFAULT_API_URL) {
    this.apiUrl = apiUrl;
  }

  /**
   * Search for documentation using the DevDocs backend
   */
  async searchDocumentation(query: string, technology?: string): Promise<string> {
    try {
      // You would implement this to query your DevDocs backend API
      // Example implementation:
      const url = new URL(`${this.apiUrl}/api/search`);
      url.searchParams.append('q', query);
      if (technology) {
        url.searchParams.append('tech', technology);
      }

      const response = await fetch(url.toString());
      
      if (!response.ok) {
        throw new Error(`Search request failed: ${response.status}`);
      }
      
      const results: DocSearchResult[] = await response.json();
      
      // Format the results into a markdown string
      return this.formatSearchResults(results);
    } catch (error) {
      console.error('Error searching documentation:', error);
      // Return fallback content
      return `Search results for "${query}"${technology ? ` in ${technology}` : ''}:\n\n` +
             `*Unable to connect to DevDocs backend. Using fallback content.*\n\n` +
             `1. **Introduction to ${query}** - Overview of ${query} concepts and usage\n` +
             `2. **${query} API Reference** - Detailed API documentation\n` +
             `3. **${query} Tutorial** - Step by step guide to using ${query}`;
    }
  }

  /**
   * Get documentation for a specific topic
   */
  async getDocumentation(topic: string, technology: string): Promise<string> {
    try {
      // You would implement this to query your DevDocs backend API
      // Example implementation:
      const url = new URL(`${this.apiUrl}/api/docs`);
      url.searchParams.append('topic', topic);
      url.searchParams.append('tech', technology);
      
      const response = await fetch(url.toString());
      
      if (!response.ok) {
        throw new Error(`Documentation request failed: ${response.status}`);
      }
      
      const docContent: string = await response.text();
      return docContent;
    } catch (error) {
      console.error('Error getting documentation:', error);
      // Return fallback content
      return `# ${topic} Documentation (${technology})\n\n` +
             `## Overview\n\n` +
             `*Unable to connect to DevDocs backend. Using fallback content.*\n\n` +
             `${topic} is a ${technology} feature that allows developers to...\n\n` +
             `## Syntax\n\n` +
             `\`\`\`${technology}\n// Example code for ${topic}\n\`\`\``;
    }
  }

  /**
   * Get a list of available documentation categories
   */
  async getAvailableTechnologies(): Promise<string> {
    try {
      // You would implement this to query your DevDocs backend API
      // Example implementation:
      const response = await fetch(`${this.apiUrl}/api/technologies`);
      
      if (!response.ok) {
        throw new Error(`Technologies request failed: ${response.status}`);
      }
      
      const technologies: TechnologyInfo[] = await response.json();
      
      // Format the technologies into a markdown list
      return technologies.map(tech => 
        `- **${tech.name}**${tech.version ? ` (${tech.version})` : ''}${tech.description ? `: ${tech.description}` : ''}`
      ).join('\n');
    } catch (error) {
      console.error('Error getting technologies:', error);
      // Return fallback content
      return "- JavaScript\n- TypeScript\n- React\n- Node.js\n- HTML\n- CSS\n- Python\n- Docker\n- Git";
    }
  }

  /**
   * Get code examples for a topic
   */
  async getCodeExamples(topic: string, technology: string): Promise<string> {
    try {
      // You would implement this to query your DevDocs backend API
      // Example implementation:
      const url = new URL(`${this.apiUrl}/api/examples`);
      url.searchParams.append('topic', topic);
      url.searchParams.append('tech', technology);
      
      const response = await fetch(url.toString());
      
      if (!response.ok) {
        throw new Error(`Examples request failed: ${response.status}`);
      }
      
      const examples: CodeExample[] = await response.json();
      
      // Format the examples into markdown
      return this.formatCodeExamples(examples, technology);
    } catch (error) {
      console.error('Error getting code examples:', error);
      // Return fallback content
      return `# Code Examples for ${topic} (${technology})\n\n` +
             `*Unable to connect to DevDocs backend. Using fallback content.*\n\n` +
             `## Basic Example\n\n` +
             `\`\`\`${technology}\n// Basic example of ${topic}\n\`\`\``;
    }
  }

  /**
   * Format search results into a markdown string
   */
  private formatSearchResults(results: DocSearchResult[]): string {
    if (results.length === 0) {
      return "No results found.";
    }
    
    let markdown = "## Search Results\n\n";
    
    results.forEach((result, index) => {
      markdown += `### ${index + 1}. ${result.title}\n`;
      if (result.description) {
        markdown += `${result.description}\n\n`;
      }
      markdown += `**Path:** ${result.path}\n\n`;
      
      // Add a snippet of the content if available
      if (result.content) {
        const snippet = result.content.substring(0, 200) + (result.content.length > 200 ? '...' : '');
        markdown += `${snippet}\n\n`;
      }
    });
    
    return markdown;
  }

  /**
   * Format code examples into a markdown string
   */
  private formatCodeExamples(examples: CodeExample[], technology: string): string {
    if (examples.length === 0) {
      return "No examples found.";
    }
    
    let markdown = "# Code Examples\n\n";
    
    examples.forEach((example, index) => {
      markdown += `## ${example.title}\n\n`;
      
      if (example.description) {
        markdown += `${example.description}\n\n`;
      }
      
      markdown += `\`\`\`${technology}\n${example.code}\n\`\`\`\n\n`;
    });
    
    return markdown;
  }
}

// Create a default instance for easy importing
export const docsIntegration = new DocsIntegration();