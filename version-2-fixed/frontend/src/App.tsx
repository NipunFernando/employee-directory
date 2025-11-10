import React, { useState, useEffect } from 'react';
import { EmployeeForm } from './components/EmployeeForm';
import { EmployeeList } from './components/EmployeeList';
import * as api from './services/api';
import { getUserInfo, getUserInfoFromCookie, login, logout, UserInfo } from './services/auth';
import './App.css';

// Define a simple type for the employee
export interface Employee {
  id: number;
  name: string;
  email: string;
  department: string;
  position: string;
  salary: number;
}

function App() {
  const [employees, setEmployees] = useState<Employee[]>([]);
  const [editingEmployee, setEditingEmployee] = useState<Employee | null>(null);
  const [userInfo, setUserInfo] = useState<UserInfo | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Check authentication and get user info
  useEffect(() => {
    const checkAuth = async () => {
      console.log('[DEBUG App] Starting authentication check...');
      try {
        // First, check for userinfo cookie (set immediately after login)
        const cookieUserInfo = getUserInfoFromCookie();
        console.log('[DEBUG App] Cookie userInfo:', cookieUserInfo ? 'found' : 'not found');
        if (cookieUserInfo) {
          console.log('[DEBUG App] Using cookie userInfo, setting user and stopping loading');
          setUserInfo(cookieUserInfo);
          setIsLoading(false);
          return;
        }

        // Otherwise, check /auth/userinfo endpoint
        console.log('[DEBUG App] No cookie, fetching from /auth/userinfo...');
        const user = await getUserInfo();
        console.log('[DEBUG App] getUserInfo returned:', user ? 'user found' : 'null');
        setUserInfo(user);
      } catch (err) {
        console.error('[DEBUG App] Error checking authentication:', err);
        setError('Failed to check authentication status');
      } finally {
        console.log('[DEBUG App] Setting isLoading to false');
        setIsLoading(false);
      }
    };

    checkAuth();
  }, []);

  const fetchEmployees = () => {
    setError(null);
    api.getEmployees()
      .then(response => {
        setEmployees(response.data.data || []);
      })
      // FIXED: Proper error handling with user-friendly messages
      .catch(err => {
        console.error('Error fetching employees:', err);
        const errorMessage = err.response?.data?.error || 'Failed to load employees. Please try again.';
        setError(errorMessage);
      });
  };

  useEffect(() => {
    if (userInfo) {
      fetchEmployees();
    }
  }, [userInfo]);

  const handleSave = () => {
    fetchEmployees();
    setEditingEmployee(null);
  };

  // Show loading state
  if (isLoading) {
    return (
      <div className="container mx-auto p-8" style={{ minHeight: '100vh', backgroundColor: '#f3f4f6', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <div className="text-center">
          <p className="text-lg">Loading...</p>
        </div>
      </div>
    );
  }

  // Show login if not authenticated
  if (!userInfo) {
    return (
      <div className="container mx-auto p-8" style={{ minHeight: '100vh', backgroundColor: '#f3f4f6', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <div className="text-center bg-white p-8 rounded-lg shadow-lg max-w-md">
          <h1 className="text-3xl font-bold mb-6" style={{ color: '#1f2937' }}>Employee Directory</h1>
          <p className="text-gray-600 mb-6">Please sign in to access the employee directory.</p>
          <button
            onClick={login}
            className="bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-6 rounded focus:outline-none focus:shadow-outline"
          >
            Sign In
          </button>
        </div>
      </div>
    );
  }

  // Show main app if authenticated
  return (
    <div className="container mx-auto p-8" style={{ minHeight: '100vh', backgroundColor: '#f3f4f6' }}>
      {/* Header with user info and logout */}
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-3xl font-bold" style={{ color: '#1f2937' }}>Employee Directory (V2 - Fixed)</h1>
        <div className="flex items-center gap-4">
          {userInfo.name && (
            <span className="text-gray-700">Welcome, {userInfo.name}</span>
          )}
          {userInfo.email && !userInfo.name && (
            <span className="text-gray-700">{userInfo.email}</span>
          )}
          <button
            onClick={logout}
            className="bg-red-600 hover:bg-red-700 text-white font-bold py-2 px-4 rounded focus:outline-none focus:shadow-outline"
          >
            Sign Out
          </button>
        </div>
      </div>
      
      {/* FIXED: Display error messages to user */}
      {error && (
        <div className="mb-4 p-4 bg-red-100 border border-red-400 text-red-700 rounded">
          {error}
          <button
            onClick={() => setError(null)}
            className="ml-4 text-red-700 hover:text-red-900 underline"
          >
            Dismiss
          </button>
        </div>
      )}
      
      <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
        <div className="md:col-span-1">
          <EmployeeForm
            employee={editingEmployee}
            onSave={handleSave}
            onCancel={() => setEditingEmployee(null)}
          />
        </div>
        <div className="md:col-span-2">
          <EmployeeList
            employees={employees}
            onEdit={setEditingEmployee}
            onDelete={handleSave}
          />
        </div>
      </div>
    </div>
  );
}

export default App;

