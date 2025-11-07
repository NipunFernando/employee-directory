import React from 'react';
import ReactDOM from 'react-dom';
import './index.css';
import App from './App';

const rootElement = document.getElementById('root');

if (!rootElement) {
  throw new Error('Failed to find the root element');
}

try {
  ReactDOM.render(
    <React.StrictMode>
      <App />
    </React.StrictMode>,
    rootElement
  );
} catch (error) {
  console.error('Error rendering React app:', error);
  // FIXED: Use textContent instead of innerHTML to prevent XSS
  rootElement.textContent = 'Error Loading App. Please check the console for more details.';
}

