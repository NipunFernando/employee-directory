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
    const response = await fetch('/auth/userinfo', {
      credentials: 'include', // Include cookies
    });
    
    if (response.status === 401) {
      // User is not authenticated
      return null;
    }
    
    if (!response.ok) {
      // FIXED: Return null for non-ok responses instead of throwing
      return null;
    }
    
    // FIXED: Read as text first to check if it's JSON before parsing
    // This prevents SyntaxError when HTML is returned
    const text = await response.text();
    
    // Check if response is HTML (common error page indicator)
    if (text.trim().toLowerCase().startsWith('<!doctype') || text.trim().startsWith('<')) {
      // Response is HTML, not JSON - return null silently
      return null;
    }
    
    // Try to parse as JSON
    try {
      const userInfo = JSON.parse(text);
      return userInfo;
    } catch (parseError) {
      // Response was not valid JSON - return null silently
      return null;
    }
  } catch (error) {
    // FIXED: Only log network/fetch errors, not JSON parse errors
    // JSON parse errors are handled above by checking text content first
    if (error instanceof TypeError && error.message.includes('fetch')) {
      console.error('Error fetching user info:', error);
    } else if (!(error instanceof SyntaxError)) {
      // Don't log SyntaxError - those are handled by text() approach above
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

