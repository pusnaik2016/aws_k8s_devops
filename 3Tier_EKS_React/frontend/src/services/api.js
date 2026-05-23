import axios from 'axios';
import API_BASE_URL from '../config/api';

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

export const getTopics = () => api.get('/topics');
export const getQuiz = (topicSlug) => api.get(`/quiz/${topicSlug}`);
export const submitQuiz = (data) => api.post('/quiz/submit', data);
export const addQuestion = (data) => api.post('/quiz/questions', data);
export const getQuestions = () => api.get('/quiz/questions');
export const bulkUploadQuestions = (data) => api.post('/quiz/questions/bulk', data);

export default api;
