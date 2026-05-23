import { render, screen } from '@testing-library/react';
import App from './App';

test('renders devops learning platform', () => {
  render(<App />);
  const linkElement = screen.getByText(/DevOps Learning Platform/i);
  expect(linkElement).toBeInTheDocument();
});
