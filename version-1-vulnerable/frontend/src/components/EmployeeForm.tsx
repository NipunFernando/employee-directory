import React, { useState, useEffect } from 'react';
import { Employee } from '../App';
import * as api from '../services/api';

interface Props {
  employee: Employee | null;
  onSave: () => void;
  onCancel: () => void;
}

const emptyForm = { name: '', email: '', department: '', position: '', salary: 0 };

export const EmployeeForm: React.FC<Props> = ({ employee, onSave, onCancel }) => {
  const [formData, setFormData] = useState(emptyForm);

  useEffect(() => {
    if (employee) {
      setFormData(employee);
    } else {
      setFormData(emptyForm);
    }
  }, [employee]);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    // VULNERABILITY (CWE-20): No Input Sanitization or Validation
    // User input is directly set into the state and sent to the API.
    // An attacker could input XSS payloads here, which are then
    // rendered by the EmployeeList component.
    setFormData(prev => ({
      ...prev,
      [name]: name === 'salary' ? parseFloat(value) : value,
    }));
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    
    // No validation logic
    const apiCall = employee
      ? api.updateEmployee(employee.id, formData)
      : api.createEmployee(formData);

    apiCall.then(() => {
      onSave();
      setFormData(emptyForm);
    })
    // VULNERABILITY: Missing error handling for save
    .catch(err => console.log("Error saving employee"));
  };

  return (
    <form onSubmit={handleSubmit} className="bg-white shadow-md rounded-lg p-6">
      <h2 className="text-xl font-semibold mb-4">{employee ? 'Edit Employee' : 'Add Employee'}</h2>
      {/* ... (Form fields for name, email, position, department, salary) ... */}
      <div className="mb-4">
        <label className="block text-sm font-medium text-gray-700">Name</label>
        <input type="text" name="name" value={formData.name} onChange={handleChange} className="mt-1 p-2 block w-full rounded-md border-gray-300 shadow-sm"/>
      </div>
      <div className="mb-4">
        <label className="block text-sm font-medium text-gray-700">Email</label>
        <input type="email" name="email" value={formData.email} onChange={handleChange} className="mt-1 p-2 block w-full rounded-md border-gray-300 shadow-sm"/>
      </div>
      <div className="mb-4">
        <label className="block text-sm font-medium text-gray-700">Position</label>
        <input type="text" name="position" value={formData.position} onChange={handleChange} className="mt-1 p-2 block w-full rounded-md border-gray-300 shadow-sm"/>
      </div>
      <div className="mb-4">
        <label className="block text-sm font-medium text-gray-700">Department</label>
        <input type="text" name="department" value={formData.department} onChange={handleChange} className="mt-1 p-2 block w-full rounded-md border-gray-300 shadow-sm"/>
      </div>
      <div className="mb-4">
        <label className="block text-sm font-medium text-gray-700">Salary</label>
        <input type="number" name="salary" value={formData.salary} onChange={handleChange} className="mt-1 p-2 block w-full rounded-md border-gray-300 shadow-sm"/>
      </div>
      <div className="flex justify-end">
        <button type="button" onClick={onCancel} className="mr-2 py-2 px-4 rounded-md border border-gray-300">Cancel</button>
        <button type="submit" className="py-2 px-4 rounded-md border border-transparent bg-indigo-600 text-white">Save</button>
      </div>
    </form>
  );
};