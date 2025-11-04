import axios from 'axios';

// VULNERABILITY (CWE-798): Hardcoded API URL (fallback)
// The API endpoint defaults to localhost, making it difficult to manage
// different environments (dev, staging, prod) and exposing
// sensitive information in the compiled source code.
// In Choreo, this should be set via REACT_APP_API_URL environment variable
const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:8080/api';

const api = axios.create({
  baseURL: API_URL,
});

export const getEmployees = () => api.get('/employees');
export const searchEmployees = (query: string) => api.get(`/employees/search?q=${query}`);
export const createEmployee = (employee: any) => api.post('/employees', employee);
export const updateEmployee = (id: number, employee: any) => api.put(`/employees/${id}`, employee);
export const deleteEmployee = (id: number) => api.delete(`/employees/${id}`);