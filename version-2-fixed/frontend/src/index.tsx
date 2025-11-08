import React from 'react';
import { createRoot } from 'react-dom/client';
import './index.css';
import App from './App';

const rootElement = document.getElementById('root');

if (!rootElement) {
  throw new Error('Failed to find the root element');
}

try {
  // FIXED: Updated to React 18's createRoot API
  const root = createRoot(rootElement);
  root.render(
    <React.StrictMode>
      <App />
    </React.StrictMode>
  );
} catch (error) {
  console.error('Error rendering React app:', error);
  // FIXED: Use textContent instead of innerHTML to prevent XSS
  rootElement.textContent = 'Error Loading App. Please check the console for more details.';
}

