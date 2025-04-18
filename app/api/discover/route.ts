import { NextResponse } from 'next/server'

// Helper function to retry a fetch operation
async function fetchWithRetry(url: string, options: RequestInit, maxRetries: number = 3, delay: number = 1000) {
  let lastError: Error | null = null;
  
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      console.log(`Attempt ${attempt + 1}/${maxRetries} to fetch ${url}`);
      const response = await fetch(url, options);
      return response;
    } catch (error) {
      console.error(`Attempt ${attempt + 1} failed:`, error);
      lastError = error as Error;
      
      // Only wait if we're going to retry
      if (attempt < maxRetries - 1) {
        console.log(`Waiting ${delay}ms before next attempt...`);
        await new Promise(resolve => setTimeout(resolve, delay));
        // Exponential backoff
        delay *= 2;
      }
    }
  }
  
  // All retries failed
  throw lastError || new Error(`Failed to fetch ${url} after ${maxRetries} attempts`);
}

export async function POST(request: Request) {
  try {
    const { url, depth = 3 } = await request.json()

    if (!url) {
      return NextResponse.json(
        { error: 'URL is required' },
        { status: 400 }
      )
    }

    // Validate depth is between 1 and 5
    const validatedDepth = Math.min(5, Math.max(1, parseInt(String(depth)) || 3))
    
    console.log('Making discover request for URL:', url, 'with depth:', validatedDepth)
    
    // Make a direct request to the backend API instead of using the discoverSubdomains function
    const INTERNAL_BACKEND_URL = process.env.BACKEND_URL || 'http://backend:24125';
    console.log('Using internal backend URL:', INTERNAL_BACKEND_URL);
    
    console.log('Sending request to backend API:', `${INTERNAL_BACKEND_URL}/api/discover`);
    
    // First, perform a connectivity test to the target URL
    try {
      console.log(`Testing direct connectivity to ${url}`);
      const directResponse = await fetch(url, { 
        method: 'GET',
        headers: { 'User-Agent': 'DevDocs-Crawler/1.0' }
      });
      console.log(`Direct connectivity test status: ${directResponse.status}`);
    } catch (error) {
      console.warn(`Direct connectivity test failed: ${error instanceof Error ? error.message : String(error)}`);
      // We continue anyway, as the backend might have different network access
    }
    
    // Use the retry function for backend requests
    const response = await fetchWithRetry(
      `${INTERNAL_BACKEND_URL}/api/discover`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ url, depth: validatedDepth }),
      },
      3, // max retries
      1000 // initial delay in ms
    );
    
    console.log('Response status from backend:', response.status)
    
    if (!response.ok) {
      let errorData;
      try {
        errorData = await response.json();
      } catch (e) {
        errorData = { error: 'Failed to parse error response' };
      }
      
      console.error('Error response from backend:', errorData)
      return NextResponse.json(
        { error: errorData.error || 'Failed to discover pages' },
        { status: response.status }
      )
    }
    
    const data = await response.json()
    console.log('Received response from backend:', data)
    console.log('Discovered pages count:', data.pages?.length || 0)
    if (data.pages?.length > 0) {
      console.log('First discovered page:', data.pages[0])
    } else {
      console.warn('No pages were discovered')
    }

    // Even if we get an empty array, we should still return it with a 200 status
    // Forward the exact response from the backend, including the job_id
    return NextResponse.json(data)
    
  } catch (error) {
    console.error('Error in discover route:', error)
    
    // Log more detailed information about the error
    if (error instanceof Error) {
      console.error('Error name:', error.name)
      console.error('Error message:', error.message)
      console.error('Error stack:', error.stack)
      
      // Check for network-related errors
      if (error.message.includes('fetch') || error.message.includes('network') || error.message.includes('ECONNREFUSED')) {
        console.error('Network error detected - possible connection issue to backend service')
        
        return NextResponse.json(
          {
            error: 'Network error - Unable to connect to backend service',
            details: error.message,
            errorType: error.name,
            pages: []
          },
          { status: 503 } // Service Unavailable
        )
      }
      
      // Check for timeout errors
      if (error.message.includes('timeout')) {
        console.error('Timeout error detected - backend service might be taking too long to respond')
        
        return NextResponse.json(
          {
            error: 'Request timed out - Backend service took too long to respond',
            details: error.message,
            errorType: error.name,
            pages: []
          },
          { status: 504 } // Gateway Timeout
        )
      }
    }
    
    // Check if it's a TypeError, which might indicate issues with the response format
    if (error instanceof TypeError) {
      console.error('TypeError detected - possible issue with response format or undefined values')
    }
    
    return NextResponse.json(
      {
        error: error instanceof Error ? error.message : 'Failed to discover pages',
        details: error instanceof Error ? error.stack : undefined,
        errorType: error instanceof Error ? error.name : 'Unknown',
        pages: []
      },
      { status: 500 }
    )
  }
}