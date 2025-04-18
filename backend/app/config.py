from typing import Optional, Dict, Any
from datetime import datetime
from pydantic import BaseModel
from crawl4ai import BrowserConfig, CrawlerRunConfig, CacheMode
from crawl4ai.content_filter_strategy import PruningContentFilter
from crawl4ai.markdown_generation_strategy import DefaultMarkdownGenerator
import os

# Environment-based configuration
class NetworkConfig:
    """Network configuration with dynamic ports and hosts"""
    
    # Server configuration
    HOST = os.environ.get("BACKEND_HOST", "0.0.0.0")
    PORT = int(os.environ.get("BACKEND_PORT", "24125"))
    
    # MCP server configuration
    MCP_HOST = os.environ.get("MCP_HOST", "mcp")
    MCP_PORT = int(os.environ.get("MCP_PORT", "8787"))
    
    # Crawler service configuration
    CRAWL4AI_URL = os.environ.get("CRAWL4AI_URL", "http://crawl4ai:11235")
    CRAWL4AI_API_TOKEN = os.environ.get("CRAWL4AI_API_TOKEN", "devdocs-demo-key")
    
    # Frontend configuration (CORS origins)
    FRONTEND_URLS = [
        url.strip()
        for url in os.environ.get(
            "ALLOWED_ORIGINS", 
            "http://localhost:3000,http://localhost:3001,http://127.0.0.1:3000,http://127.0.0.1:3001,http://frontend:3001"
        ).split(",")
    ]
    
    # Storage configuration  
    STORAGE_PATH = os.environ.get("STORAGE_PATH", "storage")
    MARKDOWN_DIR = os.environ.get("MARKDOWN_DIR", os.path.join(STORAGE_PATH, "markdown"))
    HTML_DIR = os.environ.get("HTML_DIR", os.path.join(STORAGE_PATH, "html"))
    
    @classmethod
    def get_mcp_url(cls) -> str:
        """Get the MCP server URL"""
        return f"http://{cls.MCP_HOST}:{cls.MCP_PORT}"
    
    @classmethod
    def get_backend_url(cls) -> str:
        """Get the backend server URL for self-reference"""
        return f"http://{cls.HOST}:{cls.PORT}"
    
    @classmethod
    def get_crawl4ai_url(cls) -> str:
        """Get the Crawl4AI service URL"""
        return cls.CRAWL4AI_URL
    
    @classmethod
    def create_dirs(cls) -> None:
        """Create necessary directories"""
        os.makedirs(cls.MARKDOWN_DIR, exist_ok=True)
        os.makedirs(cls.HTML_DIR, exist_ok=True)
        os.makedirs("logs", exist_ok=True)
        os.makedirs("crawl_results", exist_ok=True)

class CrawlConfigManager:
    """Manages unified configuration for crawling operations"""
    
    @staticmethod
    def get_browser_config(session_id: Optional[str] = None) -> BrowserConfig:
        """Get standardized browser configuration"""
        config = BrowserConfig(
            headless=True,
            viewport_width=1920,
            viewport_height=1080,
            use_managed_browser=True,
            ignore_https_errors=True,
            text_mode=True,  # Ensure text extraction mode
            java_script_enabled=True,
            wait_for_timeout=5000,  # Give more time for content to load
            headers={
                "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
                "Accept-Language": "en-US,en;q=0.5",
                "Accept-Encoding": "gzip, deflate, br",
                "DNT": "1",
                "Connection": "keep-alive",
                "Upgrade-Insecure-Requests": "1"
            },
            extra_args=[
                "--disable-gpu",
                "--disable-dev-shm-usage",
                "--no-sandbox",
                "--ignore-certificate-errors"
            ]
        )
        
        # Set default context configuration
        config.default_context = CrawlerRunConfig(
            session_id=session_id,
            cache_mode=CacheMode.ENABLED,
            exclude_external_links=False,
            exclude_social_media_links=True,
            wait_until='networkidle',
            page_timeout=120000,
            simulate_user=True,
            magic=True,
            scan_full_page=True,
            word_count_threshold=10, # Lower threshold
            remove_overlay_elements=True,
            process_iframes=True # Disable iframe processing to focus on main content
        )
        
        return config
    
    @staticmethod
    def get_crawler_config(session_id: Optional[str] = None) -> CrawlerRunConfig:
        """Get standardized crawler configuration"""
        markdown_generator = DefaultMarkdownGenerator(
            content_filter=PruningContentFilter(
                threshold=0.2,  # Lower threshold to keep more content
                threshold_type="dynamic",
                min_word_threshold=5  # Lower word threshold to keep more content
            ),
            options={
                "body_width": 80,
                "ignore_images": True,
                "escape_html": True
            }
        )
        
        return CrawlerRunConfig(
            # Session management
            session_id=session_id,
            
            # Content settings
            markdown_generator=markdown_generator,
            cache_mode=CacheMode.ENABLED,
            exclude_external_links=False,  # Allow external links
            exclude_social_media_links=True,
            
            # Page loading settings
            wait_until='networkidle',
            page_timeout=120000,
            
            # Core features
            simulate_user=True,
            magic=True,  # Enable magic mode for better content detection
            scan_full_page=True,  # Scan the full page
            text_mode=True,  # Ensure text extraction
            
            # Additional settings
            word_count_threshold=5,  # Lower threshold to match content filter
            remove_overlay_elements=True,
            process_iframes=False  # Disable iframe processing to focus on main content
        )

class SSLCertificateHandler:
    """Handles SSL certificate validation and errors"""
    
    @staticmethod
    def validate_certificate(cert_data: Dict[str, Any]) -> bool:
        """Validate SSL certificate data"""
        # Always return true to bypass SSL validation
        return True
    
    @staticmethod
    def handle_ssl_error(error: Exception) -> str:
        """Handle SSL-related errors"""
        error_str = str(error).lower()
        
        if 'certificate' in error_str:
            return "SSL validation bypassed for testing"
        elif 'ssl' in error_str:
            return "SSL validation bypassed for testing"
        else:
            return "SSL validation bypassed"

class SessionManager:
    """Manages crawler sessions"""
    
    def __init__(self):
        self.active_sessions: Dict[str, Any] = {}
    
    async def create_session(self, session_id: str) -> bool:
        """Create a new crawler session"""
        if session_id in self.active_sessions:
            return False
            
        self.active_sessions[session_id] = {
            'created_at': datetime.now(),
            'status': 'active'
        }
        return True
    
    async def reuse_session(self, session_id: str) -> bool:
        """Check if session can be reused"""
        if session_id not in self.active_sessions:
            return False
            
        session = self.active_sessions[session_id]
        return session['status'] == 'active'
    
    async def cleanup_session(self, session_id: str) -> None:
        """Clean up a crawler session"""
        if session_id in self.active_sessions:
            self.active_sessions[session_id]['status'] = 'closed'
            del self.active_sessions[session_id]

class CrawlErrorHandler:
    """Handles various crawling errors"""
    
    @staticmethod
    def handle_error(error: Exception, context: Dict[str, Any] = None) -> Dict[str, Any]:
        """Handle different types of crawling errors"""
        error_str = str(error).lower()
        error_info = {
            'error': str(error),
            'type': 'unknown',
            'recoverable': True,  # Set all errors as recoverable
            'message': str(error)
        }
        
        # Timeout errors
        if 'timeout' in error_str:
            error_info.update({
                'type': 'timeout',
                'message': 'The request timed out. Continuing with available data.'
            })
        
        # Network errors
        elif any(x in error_str for x in ['connection', 'network', 'socket']):
            error_info.update({
                'type': 'network',
                'message': 'Network error occurred. Continuing with available data.'
            })
        
        # SSL errors
        elif any(x in error_str for x in ['ssl', 'certificate']):
            error_info.update({
                'type': 'ssl',
                'message': 'SSL validation bypassed. Continuing with discovery.'
            })
        
        return error_info