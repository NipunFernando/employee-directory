import React, { useState, useEffect } from 'react';
import { Employee } from '../App';
import * as api from '../services/api';

interface Props {
  employee: Employee | null;
  onSave: () => void;
  onCancel: () => void;
}

const emptyForm = { name: '', email: '', department: '', position: '', salary: 0 };

// FIXED: Input validation and sanitization utilities
const validateEmail = (email: string): boolean => {
  const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
  return emailRegex.test(email);
};

const sanitizeInput = (input: string): string => {
  // Remove potentially dangerous characters
  return input
    .replace(/[<>]/g, '') // Remove < and > to prevent HTML injection
    .replace(/javascript:/gi, '') // Remove javascript: protocol
    .replace(/on\w+=/gi, '') // Remove event handlers like onclick=
    .trim();
};

const validateForm = (formData: typeof emptyForm): string | null => {
  if (!formData.name || formData.name.trim().length === 0) {
    return 'Name is required';
  }
  if (formData.name.length > 255) {
    return 'Name must be less than 255 characters';
  }
  
  if (!formData.email || formData.email.trim().length === 0) {
    return 'Email is required';
  }
  if (!validateEmail(formData.email)) {
    return 'Please enter a valid email address';
  }
  if (formData.email.length > 255) {
    return 'Email must be less than 255 characters';
  }
  
  if (formData.position && formData.position.length > 100) {
    return 'Position must be less than 100 characters';
  }
  
  if (formData.department && formData.department.length > 100) {
    return 'Department must be less than 100 characters';
  }
  
  if (formData.salary < 0) {
    return 'Salary cannot be negative';
  }
  
  return null;
};

export const EmployeeForm: React.FC<Props> = ({ employee, onSave, onCancel }) => {
  const [formData, setFormData] = useState(emptyForm);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [isSubmitting, setIsSubmitting] = useState(false);

  useEffect(() => {
    if (employee) {
      setFormData(employee);
    } else {
      setFormData(emptyForm);
    }
    setErrors({});
  }, [employee]);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    
    // FIXED: Sanitize input to prevent XSS
    const sanitizedValue = name === 'salary' 
      ? (value === '' ? 0 : parseFloat(value) || 0)
      : sanitizeInput(value);
    
    setFormData(prev => ({
      ...prev,
      [name]: sanitizedValue,
    }));
    
    // Clear error for this field when user starts typing
    if (errors[name]) {
      setErrors(prev => {
        const newErrors = { ...prev };
        delete newErrors[name];
        return newErrors;
      });
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    
    // FIXED: Validate form before submission
    const validationError = validateForm(formData);
    if (validationError) {
      setErrors({ general: validationError });
      return;
    }
    
    setIsSubmitting(true);
    setErrors({});
    
    const apiCall = employee
      ? api.updateEmployee(employee.id, formData)
      : api.createEmployee(formData);

    apiCall
      .then(() => {
        onSave();
        setFormData(emptyForm);
        setErrors({});
      })
      .catch((err) => {
        // FIXED: Proper error handling
        console.error('Error saving employee:', err);
        const errorMessage = err.response?.data?.error || 'Failed to save employee. Please try again.';
        setErrors({ general: errorMessage });
      })
      .finally(() => {
        setIsSubmitting(false);
      });
  };

  return (
    <form onSubmit={handleSubmit} className="bg-white shadow-md rounded-lg p-6">
      <h2 className="text-xl font-semibold mb-4">{employee ? 'Edit Employee' : 'Add Employee'}</h2>
      
      {/* FIXED: Display validation errors */}
      {errors.general && (
        <div className="mb-4 p-3 bg-red-100 border border-red-400 text-red-700 rounded">
          {errors.general}
        </div>
      )}
      
      <div className="mb-4">
        <label className="block text-sm font-medium text-gray-700">Name *</label>
        <input 
          type="text" 
          name="name" 
          value={formData.name} 
          onChange={handleChange} 
          className="mt-1 p-2 block w-full rounded-md border-gray-300 shadow-sm"
          required
          maxLength={255}
        />
        {errors.name && <p className="mt-1 text-sm text-red-600">{errors.name}</p>}
      </div>
      
      <div className="mb-4">
        <label className="block text-sm font-medium text-gray-700">Email *</label>
        <input 
          type="email" 
          name="email" 
          value={formData.email} 
          onChange={handleChange} 
          className="mt-1 p-2 block w-full rounded-md border-gray-300 shadow-sm"
          required
          maxLength={255}
        />
        {errors.email && <p className="mt-1 text-sm text-red-600">{errors.email}</p>}
      </div>
      
      <div className="mb-4">
        <label className="block text-sm font-medium text-gray-700">Position</label>
        <input 
          type="text" 
          name="position" 
          value={formData.position} 
          onChange={handleChange} 
          className="mt-1 p-2 block w-full rounded-md border-gray-300 shadow-sm"
          maxLength={100}
        />
        {errors.position && <p className="mt-1 text-sm text-red-600">{errors.position}</p>}
      </div>
      
      <div className="mb-4">
        <label className="block text-sm font-medium text-gray-700">Department</label>
        <input 
          type="text" 
          name="department" 
          value={formData.department} 
          onChange={handleChange} 
          className="mt-1 p-2 block w-full rounded-md border-gray-300 shadow-sm"
          maxLength={100}
        />
        {errors.department && <p className="mt-1 text-sm text-red-600">{errors.department}</p>}
      </div>
      
      <div className="mb-4">
        <label className="block text-sm font-medium text-gray-700">Salary</label>
        <input 
          type="number" 
          name="salary" 
          value={formData.salary} 
          onChange={handleChange} 
          className="mt-1 p-2 block w-full rounded-md border-gray-300 shadow-sm"
          min="0"
          step="0.01"
        />
        {errors.salary && <p className="mt-1 text-sm text-red-600">{errors.salary}</p>}
      </div>
      
      <div className="flex justify-end">
        <button 
          type="button" 
          onClick={onCancel} 
          className="mr-2 py-2 px-4 rounded-md border border-gray-300"
          disabled={isSubmitting}
        >
          Cancel
        </button>
        <button 
          type="submit" 
          className="py-2 px-4 rounded-md border border-transparent bg-indigo-600 text-white disabled:opacity-50"
          disabled={isSubmitting}
        >
          {isSubmitting ? 'Saving...' : 'Save'}
        </button>
      </div>
    </form>
  );
};

