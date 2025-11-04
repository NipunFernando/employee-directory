import React from 'react';
import ReactDOM from 'react-dom';
import './index.css';
import App from './App';

console.log('index.tsx is loading');

const rootElement = document.getElementById('root');

if (!rootElement) {
  throw new Error('Failed to find the root element');
}

console.log('Root element found, rendering React app');

try {
  ReactDOM.render(
    <React.StrictMode>
      <App />
    </React.StrictMode>,
    rootElement
  );
  console.log('React app rendered successfully');
} catch (error) {
  console.error('Error rendering React app:', error);
  rootElement.innerHTML = `
    <div style="padding: 20px; color: red;">
      <h1>Error Loading App</h1>
      <p>${error}</p>
      <p>Check the console for more details.</p>
    </div>
  `;
}

