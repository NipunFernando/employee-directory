import React, { useState, useEffect } from 'react';
import { EmployeeForm } from './components/EmployeeForm';
import { EmployeeList } from './components/EmployeeList';
import * as api from './services/api';
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
  console.log('App component is rendering');
  const [employees, setEmployees] = useState<Employee[]>([]);
  const [editingEmployee, setEditingEmployee] = useState<Employee | null>(null);

  const fetchEmployees = () => {
    api.getEmployees()
      .then(response => {
        setEmployees(response.data.data || []);
      })
      // VULNERABILITY: Missing error handling
      .catch(err => console.log("Error fetching employees"));
  };

  useEffect(() => {
    fetchEmployees();
  }, []);

  const handleSave = () => {
    fetchEmployees();
    setEditingEmployee(null);
  };

  return (
    <div className="container mx-auto p-8" style={{ minHeight: '100vh', backgroundColor: '#f3f4f6' }}>
      <h1 className="text-3xl font-bold mb-6 text-center" style={{ color: '#1f2937' }}>Employee Directory (V1 - Vulnerable)</h1>
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
            onDelete={handleSave} // Just refetch all on delete
          />
        </div>
      </div>
    </div>
  );
}

export default App;