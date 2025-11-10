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
// FIXED: Simplified to match working version-1 approach, but with better error handling
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
    
    // FIXED: Check Content-Type before parsing JSON to avoid errors
    const contentType = response.headers.get('content-type');
    if (!contentType || !contentType.includes('application/json')) {
      // Response is not JSON (might be HTML error page) - return null silently
      return null;
    }
    
    // FIXED: Try to parse JSON, catch errors gracefully (handles HTML responses)
    try {
      const userInfo = await response.json();
      return userInfo;
    } catch (parseError) {
      // Response was not valid JSON (might be HTML error page)
      // This can happen during redirects or errors - return null silently
      return null;
    }
  } catch (error) {
    // FIXED: Only log network/fetch errors, not JSON parse errors
    // JSON parse errors (SyntaxError) are handled in the inner try-catch above
    // Only log actual network/fetch errors
    if (error instanceof TypeError && error.message.includes('fetch')) {
      console.error('Error fetching user info:', error);
    } else if (!(error instanceof SyntaxError)) {
      // Don't log SyntaxError (JSON parse errors) - those are expected for HTML responses
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

