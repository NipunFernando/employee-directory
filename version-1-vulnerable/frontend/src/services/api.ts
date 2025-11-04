import axios from 'axios';

// VULNERABILITY (CWE-798): Hardcoded API URL (fallback)
// The API endpoint defaults to localhost, making it difficult to manage
// different environments (dev, staging, prod) and exposing
// sensitive information in the compiled source code.
// In Choreo, this is set via window.configs.apiUrl from /public/config.js
// For local development, fallback to localhost
const API_URL = (window as any)?.configs?.apiUrl 
  ? (window as any).configs.apiUrl 
  : (process.env.REACT_APP_API_URL || 'http://localhost:8080/api');

const api = axios.create({
  baseURL: API_URL,
});

export const getEmployees = () => api.get('/employees');
export const searchEmployees = (query: string) => api.get(`/employees/search?q=${query}`);
export const createEmployee = (employee: any) => api.post('/employees', employee);
export const updateEmployee = (id: number, employee: any) => api.put(`/employees/${id}`, employee);
export const deleteEmployee = (id: number) => api.delete(`/employees/${id}`);