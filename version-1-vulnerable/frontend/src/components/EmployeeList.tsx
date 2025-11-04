import React from 'react';
import { Employee } from '../App';
import * as api from '../services/api';

interface Props {
  employees: Employee[];
  onEdit: (employee: Employee) => void;
  onDelete: () => void;
}

export const EmployeeList: React.FC<Props> = ({ employees, onEdit, onDelete }) => {
  
  const handleDelete = (id: number) => {
    if (window.confirm('Are you sure you want to delete this employee?')) {
      api.deleteEmployee(id).then(onDelete);
    }
  };

  return (
    <div className="bg-white shadow-md rounded-lg overflow-hidden">
      <table className="min-w-full divide-y divide-gray-200">
        <thead className="bg-gray-50">
          <tr>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Name</th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Position</th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Email</th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Actions</th>
          </tr>
        </thead>
        <tbody className="bg-white divide-y divide-gray-200">
          {employees.map((emp) => (
            <tr key={emp.id}>
              <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">{emp.name}</td>
              <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-700">
                {/* VULNERABILITY (CWE-79): Cross-Site Scripting (XSS)
                  Using dangerouslySetInnerHTML allows any HTML/JavaScript stored in
                  the 'position' field to be executed by the browser.
                  An attacker could set an employee's position to:
                  '<img src=x onerror=alert("XSS-from-position")>'
                  This will be flagged by SCA and SAST tools.
                */}
                <span dangerouslySetInnerHTML={{ __html: emp.position }} />
              </td>
              <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-700">{emp.email}</td>
              <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                <button onClick={() => onEdit(emp)} className="text-indigo-600 hover:text-indigo-900 mr-4">Edit</button>
                <button onClick={() => handleDelete(emp.id)} className="text-red-600 hover:text-red-900">Delete</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};