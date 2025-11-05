import axios, { AxiosError } from 'axios';

// VULNERABILITY (CWE-798): Hardcoded API URL (fallback)
// The API endpoint defaults to localhost, making it difficult to manage
// different environments (dev, staging, prod) and exposing
// sensitive information in the compiled source code.
// In Choreo, this is set via window.configs.apiUrl from /public/config.js
// For local development, fallback to localhost
const getApiUrl = () => {
  const choreoApiUrl = (window as any)?.configs?.apiUrl;
  if (choreoApiUrl) {
    // In Choreo, use the relative path from window.configs.apiUrl
    // Example: /choreo-apis/adeepacostoptimizer/employee-directory-backen/v1
    return choreoApiUrl;
  }
  // Local development fallback
  return process.env.REACT_APP_API_URL || 'http://localhost:8080/api';
};

const API_URL = getApiUrl();

const api = axios.create({
  baseURL: API_URL,
  withCredentials: true, // Include cookies for Choreo managed authentication
});

// Interceptor to handle 401 errors and redirect to login
api.interceptors.response.use(
  (response) => response,
  (error: AxiosError) => {
    if (error.response?.status === 401) {
      // Session expired or not authenticated - redirect to login
      // Only redirect if we're not already on an auth page to prevent loops
      if (!window.location.pathname.startsWith('/auth/')) {
        console.log('Unauthorized (401) - redirecting to login');
        window.location.href = '/auth/login';
      }
    }
    return Promise.reject(error);
  }
);

export const getEmployees = () => api.get('/employees');
export const searchEmployees = (query: string) => api.get(`/employees/search?q=${query}`);
export const createEmployee = (employee: any) => api.post('/employees', employee);
export const updateEmployee = (id: number, employee: any) => api.put(`/employees/${id}`, employee);
export const deleteEmployee = (id: number) => api.delete(`/employees/${id}`);