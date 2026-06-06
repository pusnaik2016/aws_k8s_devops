import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { getTopics } from '../services/api';

function Home() {
  const [topics, setTopics] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchTopics = async () => {
      try {
        const response = await getTopics();
        setTopics(response.data);
        setLoading(false);
      } catch (err) {
        setError(err.message);
        setLoading(false);
      }
    };
    fetchTopics();
  }, []);

  if (loading) {
    return (
      <div className="flex justify-center items-center h-64">
        <div className="text-xl text-gray-600">Loading...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="container mx-auto p-4">
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded">
          <p className="font-bold">Error loading topics: {error}</p>
          <p>Please make sure the backend server is running and accessible</p>
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto p-8">
      <div className="text-center mb-12">
        <h1 className="text-4xl font-bold text-gray-800 mb-4">
          Welcome to DevOps Learning Platform
        </h1>
        <p className="text-xl text-gray-600">
          Master DevOps concepts through interactive learning and quizzes.
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {topics.map((topic) => (
          <div key={topic.id} className="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow">
            <h2 className="text-2xl font-bold text-gray-800 mb-3">{topic.title}</h2>
            <p className="text-gray-600 mb-4">{topic.description}</p>
            <Link
              to={`/quiz/${topic.id}`}
              className="inline-block bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition-colors"
            >
              Start Quiz
            </Link>
          </div>
        ))}
      </div>
    </div>
  );
}

export default Home;
