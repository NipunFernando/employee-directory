import Cookies from 'js-cookie';

// User info interface
export interface UserInfo {
  sub?: string;
  email?: string;
  name?: string;
  [key: string]: any;
}

// Get user info from cookie (set by Choreo after login)
export const getUserInfoFromCookie = (): UserInfo | null => {
  try {
    const encodedUserInfo = Cookies.get('userinfo');
    if (!encodedUserInfo) {
      return null;
    }
    
    // Decode the base64 encoded value
    const userInfo = JSON.parse(atob(encodedUserInfo));
    
    // Clear the cookie after reading (recommended by Choreo)
    Cookies.remove('userinfo', { path: '/' });
    
    return userInfo;
  } catch (error) {
    console.error('Error reading userinfo cookie:', error);
    return null;
  }
};

// Get user info from /auth/userinfo endpoint
// FIXED: Use text() first to check content before parsing JSON to avoid SyntaxError
export const getUserInfo = async (): Promise<UserInfo | null> => {
  try {
    console.log('[DEBUG] Fetching /auth/userinfo...');
    const response = await fetch('/auth/userinfo', {
      credentials: 'include', // Include cookies
      redirect: 'manual', // FIXED: Handle redirects manually to prevent loops
    });
    
    console.log('[DEBUG] Response status:', response.status, 'ok:', response.ok);
    console.log('[DEBUG] Response headers:', {
      'content-type': response.headers.get('content-type'),
      'location': response.headers.get('location'),
    });
    
    // Handle redirect responses (3xx)
    if (response.status >= 300 && response.status < 400) {
      console.log('[DEBUG] Redirect response detected, returning null');
      // Redirect response - user likely needs to authenticate
      return null;
    }
    
    if (response.status === 401) {
      console.log('[DEBUG] 401 Unauthorized, returning null');
      // User is not authenticated
      return null;
    }
    
    if (!response.ok) {
      console.log('[DEBUG] Response not ok, returning null');
      // FIXED: Return null for non-ok responses instead of throwing
      return null;
    }
    
    // FIXED: Read as text first to check if it's JSON before parsing
    // This prevents SyntaxError when HTML is returned
    let text: string;
    try {
      text = await response.text();
      console.log('[DEBUG] Response text length:', text.length);
      console.log('[DEBUG] Response text preview (first 200 chars):', text.substring(0, 200));
    } catch (textError) {
      console.log('[DEBUG] Error reading response text:', textError);
      // If we can't read the text, return null silently
      return null;
    }
    
    // Check if response is HTML (common error page indicator)
    const trimmedText = text.trim();
    if (trimmedText.toLowerCase().startsWith('<!doctype') || trimmedText.startsWith('<')) {
      console.log('[DEBUG] Response is HTML, returning null');
      // Response is HTML, not JSON - return null silently
      return null;
    }
    
    // Try to parse as JSON
    try {
      const userInfo = JSON.parse(text);
      console.log('[DEBUG] Successfully parsed JSON, userInfo:', userInfo);
      return userInfo;
    } catch (parseError) {
      console.log('[DEBUG] Failed to parse as JSON:', parseError);
      // Response was not valid JSON - return null silently (don't log)
      return null;
    }
  } catch (error) {
    // FIXED: Only log network/fetch errors, not JSON parse errors
    // JSON parse errors (SyntaxError) are handled above and should never reach here
    // Only log actual network/fetch errors
    console.log('[DEBUG] Outer catch block, error type:', error?.constructor?.name, error);
    if (error instanceof SyntaxError) {
      // SyntaxError should be caught by inner try-catch, but if it somehow reaches here, don't log
      return null;
    }
    if (error instanceof TypeError && error.message.includes('fetch')) {
      console.error('Error fetching user info:', error);
    } else {
      // Log other errors (but not SyntaxError)
      console.error('Error fetching user info:', error);
    }
    return null;
  }
};

// Login - redirect to Choreo login
export const login = () => {
  window.location.href = '/auth/login';
};

// Logout - redirect to Choreo logout
export const logout = () => {
  const sessionHint = Cookies.get('session_hint');
  const logoutUrl = sessionHint 
    ? `/auth/logout?session_hint=${sessionHint}`
    : '/auth/logout';
  
  // Clear any stored user info
  Cookies.remove('userinfo', { path: '/' });
  Cookies.remove('session_hint', { path: '/' });
  
  window.location.href = logoutUrl;
};

// Check if user is authenticated
export const isAuthenticated = async (): Promise<boolean> => {
  const userInfo = await getUserInfo();
  return userInfo !== null;
};

