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
      throw new Error(`Failed to get user info: ${response.status}`);
    }
    
    const userInfo = await response.json();
    return userInfo;
  } catch (error) {
    console.error('Error fetching user info:', error);
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

