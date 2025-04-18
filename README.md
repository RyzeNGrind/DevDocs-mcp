# DevDocs Explorer

A comprehensive solution for exploring web development documentation with AI assistant integration via the Model Context Protocol (MCP).

## Project Structure

The project follows a monorepo structure with clearly separated components:

```
/DevDocs/
├── backend/                # Python FastAPI backend for documentation crawling and management
│   ├── app/                # Backend application code
│   │   ├── main.py         # FastAPI entry point and API routes
│   │   ├── config.py       # Configuration with NetworkConfig for dynamic ports
│   │   ├── crawler.py      # Web page discovery and crawling logic
│   │   ├── status_manager.py # Manages job states and statuses
│   │   └── utils.py        # Shared utility functions
│   ├── venv/               # Python virtual environment
│   └── requirements.txt    # Python dependencies
├── devdocs-mcp/            # TypeScript MCP server for Cloudflare Workers
│   ├── src/                # Source code
│   │   ├── app.ts          # Hono app with API routes
│   │   ├── config.ts       # Environment configuration module
│   │   ├── index.ts        # Entry point and Durable Object definition
│   │   └── integrations.ts # Integration with documentation services
│   ├── static/             # Static files served by the MCP server
│   │   └── index.html      # Landing page
│   └── package.json        # MCP server dependencies
├── scripts/                # Utility scripts for the monorepo
│   ├── clean.js            # Cleanup redundancies and organize codebase
│   ├── setup.js            # Set up the entire project and dependencies
│   └── start.js            # Start all services with proper configuration
├── storage/                # Shared storage (markdown and HTML files)
│   ├── markdown/           # Markdown content for MCP
│   └── html/               # HTML content
├── .env                    # Environment variables for all services
└── package.json            # Root project configuration
```

## Architecture

The DevDocs Explorer uses a multi-tier architecture with several key components:

### Backend Service (FastAPI)

The Python backend handles crawling web documentation and converting it to markdown format:

- **API Layer**: FastAPI provides REST endpoints for discovery, crawling, and status tracking
- **Crawler Engine**: Responsible for crawling web pages and extracting content
- **Storage Manager**: Handles file storage and organization
- **Configuration System**: Uses environment variables for dynamic configuration

### MCP Server (Cloudflare Workers)

The TypeScript MCP server provides AI assistant integration:

- **Durable Objects**: Maintains stateful connections with AI assistants
- **MCP Protocol**: Implements the Model Context Protocol for AI tools
- **API Routes**: Provides HTTP endpoints for various operations
- **Fallback System**: Gracefully handles service unavailability

### Integration Layer

Connects the backend and MCP server:

- **Shared Storage**: Both services use the same storage directory
- **Configuration Bridge**: Environment variables connect the services
- **Error Handling**: Services gracefully handle connection issues

## Architectural Decisions

### ADR-1: Monorepo Structure

**Decision**: Use a monorepo approach with shared configuration and dependencies.

**Rationale**:
- Simplified deployment and management
- Shared configuration between services
- Single source of truth for documentation storage
- Easier to maintain consistency across services

### ADR-2: Dynamic Configuration

**Decision**: Use environment variables and a centralized configuration system.

**Rationale**:
- Supports different deployment environments
- Prevents hardcoded values that cause connection issues
- Simplifies configuration management
- Enables container-based deployment

### ADR-3: Shared Storage

**Decision**: Use a centralized storage directory structure with symlinks.

**Rationale**:
- Prevents duplication of data
- Ensures consistency between services
- Simplifies backup and management
- Supports both local and containerized deployments

### ADR-4: Cloudflare Workers for MCP

**Decision**: Implement MCP server using Cloudflare Workers with Durable Objects.

**Rationale**:
- Serverless architecture reduces costs
- Durable Objects provide necessary stateful connections
- Global edge deployment for low latency
- Free tier availability for development and personal use

## Key Files and Their Functions

### Backend (Python)

- **app/main.py**: Main FastAPI application with API routes for crawling and documentation management
- **app/config.py**: Configuration including NetworkConfig for dynamic ports and connection settings
- **app/crawler.py**: Discovery and crawling logic for extracting documentation from websites
- **app/status_manager.py**: Manages job status for asynchronous crawling operations

### MCP Server (TypeScript)

- **src/index.ts**: Entry point with Durable Object definition for the MCP server
- **src/app.ts**: Hono app with routes for MCP communication and static file serving
- **src/config.ts**: Environment-based configuration with validation and defaults
- **src/integrations.ts**: Integration with documentation sources and services

### Scripts (Node.js)

- **scripts/setup.js**: Sets up the project, dependencies, and directory structure
- **scripts/start.js**: Starts all services with proper environment configuration
- **scripts/clean.js**: Cleans up redundancies and ensures proper organization

## Agent Patterns Implementation

DevDocs Explorer implements several Cloudflare Agent patterns within free tier limits:

### 1. Prompt Chaining

The MCP server supports prompt chaining by:
- Converting documentation to structured markdown
- Maintaining a hierarchy for documentation topics
- Enabling step-by-step documentation exploration

**Implementation**: `devdocs-mcp/src/index.ts` implements sequence management for document retrieval.

### 2. Routing

Intelligent classification and routing of user queries:
- Query analysis to determine relevant documentation sections
- Categorization by technology and topic
- Fallback strategies for ambiguous queries

**Implementation**: Handled in search functionality in `devdocs-mcp/src/integrations.ts`.

### 3. Parallelization (Free Tier Optimized)

Efficient concurrent operations within free tier limits:
- Crawling multiple pages within rate limits
- Batch processing of documentation updates
- Staggered operations to prevent resource exhaustion

**Implementation**: Crawler parallel operations in `backend/app/crawler.py`.

### 4. State Management

Durable Objects provide efficient state management:
- Persistent connections with AI assistants
- Transaction-based state updates
- Efficient hibernation to minimize resource usage

**Implementation**: Implemented in `devdocs-mcp/src/index.ts` with Durable Objects.

## Free Tier Optimization

The system is optimized to work within free tier limits:

1. **Cloudflare Workers Free Tier**:
   - 100,000 requests per day
   - Up to 30 Workers scripts
   - 128 MB of storage
   - Automatic hibernation during inactivity

2. **Resource Optimization**:
   - Efficient caching strategies
   - Document chunking to stay within size limits
   - Batch operations to minimize request counts
   - Rate limiting to prevent exceeding quotas

3. **Storage Efficiency**:
   - Compression of stored documentation
   - Deduplication of common content
   - Selective crawling to focus on essential content

## Getting Started

Follow these steps to set up and run the project:

1. **Install dependencies**:

```bash
npm install
```

2. **Set up the project**:

```bash
npm run setup
```

3. **Start the services**:

```bash
npm start
```

4. **Access the services**:

- MCP Server: http://localhost:8787
- Backend API: http://localhost:24125

## Connecting to AI Assistants

### Claude

To connect Claude to your MCP server:

```bash
npx mcp-remote http://localhost:8787/sse
```

### Cursor

In Cursor settings:

1. Go to `Settings > AI > Model Context Protocol`
2. Add a new server with:
   - Type: `command`
   - Command: `npx mcp-remote http://localhost:8787/sse`

## Deployment to Cloudflare

For deploying the MCP server to Cloudflare Workers:

1. Set up your Cloudflare account and Wrangler CLI
2. Update your Cloudflare credentials:

```bash
npx wrangler login
```

3. Deploy to Cloudflare:

```bash
npm run deploy
```

4. Update your MCP connection URL to the deployed worker's URL

## Contributing

Contributions are welcome! Please see our [contribution guidelines](CONTRIBUTING.md) for details.

## License

MIT License - see the [LICENSE](LICENSE) file for details.

# DevDocs by CyberAGI 🚀

<div align="center">
  <img src="assets/image.png" alt="DevDocs Interface" width="800">


  <p align="center">
    <strong>Turn Weeks of Documentation Research into Hours of Productive Development</strong>
  </p>

  <p align="center">
    <a href="#-perfect-for">Perfect For</a> •
    <a href="#-features">Features</a> •
    <a href="#-why-devdocs">Why DevDocs</a> •
    <a href="#-getting-started">Getting Started</a> •
    <a href="#-scripts-and-their-purpose">Scripts</a> •
    <a href="#-pricing-comparison">Compare to FireCrawl</a> •
    <a href="#-join-our-community">Discord</a>
  </p>
</div>

<a href="https://trackgit.com">
<img src="https://us-central1-trackgit-analytics.cloudfunctions.net/token/ping/m9io6qxdhz9wzpdse4vm" alt="trackgit-views" />
</a>

## 🎯 Perfect For

### 🏢 Enterprise Software Developers
Skip weeks of reading documentation and dealing with technical debt. Implement ANY technology faster by letting DevDocs handle the heavy lifting of documentation understanding.

### 🕸️ Web Scrapers
Pull entire contents of websites with Smart Discovery of Child URLs up to level 5. Perfect for both internal and external website documentation with intelligent crawling.

### 👥 Development Teams
Leverage internal documentation with built-in MCP servers and Claude integration for intelligent data querying. Transform your team's knowledge base into an actionable resource.

### 🚀 Indie Hackers
DevDocs + VSCode(cline) + Your Idea = Ship products fast with ANY technology. No more getting stuck in documentation hell when building your next big thing.

## ✨ Features

### 🧠 Intelligent Crawling
- **Smart Depth Control**: Choose crawl depth from 1-5 levels
- **Automatic Link Discovery**: Finds and categorizes all related content
- **Selective Crawling**: Pick exactly what you want to extract
- **Child URL Detection**: Automatically discovers and maps website structure

### ⚡ Performance & Speed
- **Parallel Processing**: Crawl multiple pages simultaneously
- **Smart Caching**: Never waste time on duplicate content
- **Lazy Loading Support**: Handles modern web apps effortlessly
- **Rate Limiting**: Respectful crawling that won't overload servers

### 🎯 Content Processing
- **Clean Extraction**: Get content without the fluff
- **Multiple Formats**: Export to MD or JSON for LLM fine-tuning
- **Structured Output**: Logically organized content
- **MCP Server Integration**: Ready for AI processing

### 🛡️ Enterprise Features
- **Error Recovery**: Auto-retry on failures
- **Full Logging**: Track every operation
- **API Access**: Integrate with your tools
- **Team Management**: Multiple seats and roles

## 🤔 Why DevDocs?

### The Problem
Documentation is everywhere and LLMs are OUTDATED in their knowledge. Reading it, understanding it, and implementing it takes weeks of research and development even for senior engineers. **We cut down that time to hours.**

### Our Solution
DevDocs brings documentation to you. Point it at any tech documentation URL, and watch as it:
1. Discovers all related pages to that technology
2. Extracts meaningful content without the fluff
3. Organizes information logically inside an MCP server ready for your LLM to query
4. Presents it in a clean, searchable format in MD or JSON for finetuning LLM purpose

🔥 We want anyone in the world to have the ability to build amazing products quickly using the most cutting edge LLM technology. 

## 💰 Pricing Comparison

| Feature | DevDocs | Firecrawl |
|---------|---------|-----------|
| Free Tier | Unlimited pages | None |
| Starting Price | Free Forever | $16/month |
| Enterprise Plan | Custom | $333/month |
| Crawl Speed | 1000/min | 20/min |
| Depth Levels | Up to 5 | Limited |
| Team Seats | Unlimited | 1-5 seats |
| Export Formats | MD, JSON, LLM-ready MCP servers | Limited formats |
| API Access | Coming Soon | Limited |
| Model Context Protocol Integration | ✅ | ❌ |
| Support | Priority Available via Discord | Standard only |
| Self-hosted (free use) | ✅ | ❌ |

## 🚀 Getting Started

DevDocs is designed to be easy to use with Docker, requiring minimal setup for new users.

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) installed on your system
- Git for cloning the repository

### Quick Start with Docker (Recommended)

For Mac/Linux users:
```bash
# Clone the repository
git clone https://github.com/cyberagiinc/DevDocs.git

# Navigate to the project directory
cd DevDocs

# Configure environment variables
# Copy the template file to .env
cp .env.template .env

# Ensure NEXT_PUBLIC_BACKEND_URL in .env is set correctly (e.g., http://localhost:24125)
# This allows the frontend (running in your browser) to communicate with the backend service.


# Start all services using Docker
./docker-start.sh
```

For Windows users: Experimental Only (Not Tested Yet)
```cmd
# Clone the repository
git clone https://github.com/cyberagiinc/DevDocs.git

# Navigate to the project directory

cd DevDocs

# Configure environment variables
# Copy the template file to .env

copy .env.template .env

# Ensure NEXT_PUBLIC_BACKEND_URL in .env is set correctly (e.g., http://localhost:24125)

# This allows the frontend (running in your browser) to communicate with the backend service.

# Prerequisites: Install WSL 2 and Docker Desktop
# Docker Desktop for Windows requires WSL 2. Please ensure you have WSL 2 installed and running first.
# 1. Install WSL 2: Follow the official Microsoft guide: https://learn.microsoft.com/en-us/windows/wsl/install
# 2. Install Docker Desktop for Windows: Download and install from the official Docker website. Docker Desktop includes Docker Compose.



# Start all services using Docker
docker-start.bat
```
<details>
<summary>Note for Windows Users</summary>

> If you encounter permission issues, you may need to run the script as administrator or manually set permissions on the logs, storage, and crawl_results directories. The script uses the `icacls` command to set permissions, which might require elevated privileges on some Windows systems.
>
> **Manually Setting Permissions on Windows**:
>
> If you need to manually set permissions, you can do so using either the Windows GUI or command line:
>
> **Using Windows Explorer**:
> 1. Right-click on each directory (logs, storage, crawl_results)
> 2. Select "Properties"
> 3. Go to the "Security" tab
> 4. Click "Edit" to change permissions
> 5. Click "Add" to add users/groups
> 6. Type "Everyone" and click "Check Names"
> 7. Click "OK"
> 8. Select "Everyone" in the list
> 9. Check "Full control" under "Allow"
> 10. Click "Apply" and "OK"
>
> **Using Command Prompt (as Administrator)**:
> ```cmd
> icacls logs /grant Everyone:F /T
> icacls storage /grant Everyone:F /T
> icacls crawl_results /grant Everyone:F /T
> ```
</details> 

<details>
<summary>Note about docker-compose.yml on Windows</summary>

> If you encounter issues with the docker-compose.yml file (such as "Top-level object must be a mapping" error), the `docker-start.bat` script automatically fixes this by ensuring the file has the correct format and encoding. This fix is applied every time you run the script, so you don't need to manually modify the file.
</details>



This single command will:
1. Create all necessary directories
2. Set appropriate permissions
3. Build and start all Docker containers
4. Monitor the services to ensure they're running properly

### Accessing DevDocs

Once the services are running:
- Frontend UI: http://localhost:3001
- Backend API: http://localhost:24125
- Crawl4AI Service: http://localhost:11235

### Logs and Monitoring

When using Docker, logs can be accessed :

1. **Container Logs** (recommended for debugging):
   ```bash
   # View logs from a specific container
   docker logs devdocs-frontend
   docker logs devdocs-backend
   docker logs devdocs-mcp
   docker logs devdocs-crawl4ai
   
   # Follow logs in real-time
   docker logs -f devdocs-backend
   ```

To stop all services, press `Ctrl+C` in the terminal where docker-start is running.

## 📜 Scripts and Their Purpose

DevDocs includes various utility scripts to help with development, testing, and maintenance. Here's a quick reference:

### Startup Scripts
- `start.sh` / `start.bat` / `start.ps1` - Start all services (frontend, backend, MCP) for local development.
- `docker-start.sh` / `docker-start.bat` - Start all services using Docker containers.

### MCP Server Scripts
- `check_mcp_health.sh` - Verify the MCP server's health and configuration status.
- `restart_and_test_mcp.sh` - Restart Docker containers with updated MCP configuration and test connectivity.

### Crawl4AI Scripts
- `check_crawl4ai.sh` - Check the status and health of the Crawl4AI service.
- `debug_crawl4ai.sh` - Run Crawl4AI in debug mode with verbose logging for troubleshooting.
- `test_crawl4ai.py` - Run tests against the Crawl4AI service to verify functionality.
- `test_from_container.sh` - Test the Crawl4AI service from within a Docker container.

### Utility Scripts
- `view_result.sh` - Display crawl results in a formatted view.
- `find_empty_folders.sh` - Identify empty directories in the project structure.
- `analyze_empty_folders.sh` - Analyze empty folders and categorize them by risk level.
- `verify_reorganization.sh` - Verify that code reorganization was successful.

These scripts are organized in the following directories:
- Root directory: Main scripts for common operations
- `scripts/general/`: General utility scripts
- `scripts/docker/`: Docker-specific scripts
- `scripts/mcp/`: MCP server management scripts
- `scripts/test/`: Testing and verification scripts

## 🌍 Built for Developers, by Developers

DevDocs is more than a tool—it's your documentation companion that:
- **Saves Time**: Turn weeks of research into hours
- **Improves Understanding**: Get clean, organized documentation
- **Enables Innovation**: Build faster with any technology
- **Supports Teams**: Share knowledge efficiently
- **LLM READY**: Modern times require modern solutions, using devdocs with LLM is extremely easy and intuitive. With minimal configuration you can run Devdocs and Claude App and  recognizes DevDocs's MCP server ready to chat with your data. 

## 🛠️ Setting Up the Cline/Roo Cline for Rapid software development.

1. **Open the "Modes" Interface**  
   - In **Roo Code**, click the **+** to create a new Mode-Specific Prompts.
   <br>
   
2. **Name**  
   - Give the mode a **Name** (e.g., `Research_MCP`).  
   <br>
3. **Role Definition Prompt**
  <details>
  <summary>Prompt</summary>

```
Expertise and Personality: Expertise: Developer documentation retrieval, technical synthesis, and documentation search. Personality: Systematic, detail-oriented, and precise. Provide well-structured answers with clear references to documentation sections.

Behavioral Mandate: Always use the Table Of Contents and Section Access tools when addressing any query regarding the MCP documentation. Maintain clarity, accuracy, and traceability in your responses.
```
  </details>
 <br>

4. **Mode-Specific Custom Instructions Prompt**
<details>
<summary> Prompt </summary>


```
1. Table Of Contents Tool: Returns a full or filtered list of documentation topics. 
2. Section Access Tool: Retrieves the detailed content of specific documentation sections.

General Process: Query Interpretation: Parse the user's query to extract key topics, keywords, and context. Identify the likely relevant sections (e.g., API configurations, error handling) from the query.

Discovery via Table Of Contents: Use the Table Of Contents tool to search the documentation index for relevant sections. Filter or scan titles and metadata for matching keywords.

Drill-Down Using Section Access: For each identified relevant document or section, use the Section Access tool to retrieve its content. If multiple parts are needed, request all related sections to ensure comprehensive coverage.

Synthesis and Response Formation: Combine the retrieved content into a coherent and complete answer. Reference section identifiers or document paths for traceability. Validate that every aspect of the query has been addressed.

Error Handling: If no matching sections are found, adjust the search parameters and retry. Clearly report if the query remains ambiguous or if no relevant documentation is available.

Mandatory Tool Usage: 
Enforcement: Every time a query is received that requires information from the MCP server docs, the agent MUST first query the Table Of Contents tool to list potential relevant topics, then use the Section Access tool to retrieve the necessary detailed content.

Search & Retrieve Workflow: 
Interpret and Isolate: Identify the key terms and data points from the user's query.

Index Lookup: Immediately query the Table Of Contents tool to obtain a list of relevant documentation sections.

Targeted Retrieval: For each promising section, use the Section Access tool to get complete content.

Information Synthesis: Merge the retrieved content, ensuring all necessary details are included and clearly referenced.

Fallback and Clarification: If initial searches yield insufficient data, adjust the query parameters and retrieve additional sections as needed.

Custom Instruction Loading: Additional custom instructions specific to Research_MCP mode may be loaded from the .clinerules-research-mcp file in your workspace. These may include further refinements or constraints based on evolving documentation structures or query types.

Final Output Construction: The final answer should be organized, directly address the query, and include clear pointers (e.g., section names or identifiers) back to the MCP documentation. Ensure minimal redundancy while covering all necessary details.
```

</details>
 <br>

## 🤝 Join Our Community

- 🌟 [Star us on GitHub](https://github.com/cyberagi/devdocs)
- 👋🏽 [Reach out to our founder on Linkedin](https://www.linkedin.com/in/shubhamkhichi/)
- 💬 [Join our Discord Community](https://discord.gg/2594NueRg8)

## 🏆 Success Stories

"DevDocs turned our 3-week implementation timeline into 2 days. It's not just a crawler, it's a development accelerator." - *Senior Engineer at Fortune 100 Company*

"Launched my SaaS in half the time by using DevDocs to understand and implement new technologies quickly." - *Successful Indie Hacker*


## 📝 Technology Partners

<img src="assets/image-6.png" width="200" height="100"> <img src="assets/image-7.png" width="250" height="100"> <img src="assets/image-8.png" width="300" height="100">

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=cyberagiinc/DevDocs&type=Timeline)](https://star-history.com/#cyberagiinc/DevDocs&Timeline)

<p align="center">Made with ❤️ by <a href="https://www.cyberagi.ai">CyberAGI Inc</a> in 🇺🇸</p>

<p align="center">
  <sub>Make Software Development Better Again <a href="https://github.com/cyberagi/devdocs">Contribute to DevDocs</a></sub>
</p>

