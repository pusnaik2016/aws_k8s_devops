import React, { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { getQuiz, submitQuiz } from '../services/api';

function Quiz() {
  const { topic } = useParams();
  const [quiz, setQuiz] = useState(null);
  const [answers, setAnswers] = useState({});
  const [result, setResult] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchQuiz = async () => {
      try {
        const response = await getQuiz(topic);
        setQuiz(response.data);
        setLoading(false);
      } catch (err) {
        setError(err.message);
        setLoading(false);
      }
    };
    fetchQuiz();
  }, [topic]);

  const handleAnswer = (questionId, answerIndex) => {
    setAnswers(prev => ({
      ...prev,
      [questionId]: answerIndex
    }));
  };

  const handleSubmit = async () => {
    try {
      const response = await submitQuiz({
        topic: topic,
        answers: answers
      });
      setResult(response.data);
    } catch (err) {
      setError(err.message);
    }
  };

  if (loading) {
    return (
      <div className="flex justify-center items-center h-64">
        <div className="text-xl text-gray-600">Loading quiz...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="container mx-auto p-4">
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded">
          <p>{error}</p>
        </div>
      </div>
    );
  }

  if (result) {
    return (
      <div className="container mx-auto p-8">
        <div className="max-w-2xl mx-auto bg-white rounded-lg shadow-md p-8">
          <h2 className="text-3xl font-bold text-center mb-6">Quiz Results</h2>
          <div className="text-center">
            <div className="text-6xl font-bold text-blue-600 mb-4">
              {Math.round(result.score)}%
            </div>
            <p className="text-xl text-gray-600 mb-8">
              You got {result.correct} out of {result.total} questions correct
            </p>
            <div className="space-x-4">
              <Link
                to={`/quiz/${topic}`}
                onClick={() => window.location.reload()}
                className="inline-block bg-blue-600 text-white px-6 py-3 rounded-lg hover:bg-blue-700"
              >
                Try Again
              </Link>
              <Link
                to="/"
                className="inline-block bg-gray-600 text-white px-6 py-3 rounded-lg hover:bg-gray-700"
              >
                Back to Topics
              </Link>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto p-8">
      <div className="max-w-3xl mx-auto">
        <h1 className="text-3xl font-bold text-gray-800 mb-2">{quiz.title}</h1>
        <p className="text-gray-600 mb-8">
          Showing {quiz.selected_questions} questions from a pool of {quiz.total_questions} available questions.
        </p>

        {quiz.questions.map((question, index) => (
          <div key={question.id} className="bg-white rounded-lg shadow-md p-6 mb-6">
            <h3 className="text-lg font-semibold mb-4">
              {index + 1}. {question.question}
            </h3>
            <div className="space-y-3">
              {question.options.map((option, optIndex) => (
                <label
                  key={optIndex}
                  className={`flex items-center p-3 rounded-lg cursor-pointer border-2 transition-colors ${
                    answers[question.id] === optIndex
                      ? 'border-blue-500 bg-blue-50'
                      : 'border-gray-200 hover:border-gray-300'
                  }`}
                >
                  <input
                    type="radio"
                    name={`question-${question.id}`}
                    value={optIndex}
                    checked={answers[question.id] === optIndex}
                    onChange={() => handleAnswer(question.id, optIndex)}
                    className="mr-3"
                  />
                  <span>{option}</span>
                </label>
              ))}
            </div>
          </div>
        ))}

        <button
          onClick={handleSubmit}
          disabled={Object.keys(answers).length !== quiz.questions.length}
          className={`w-full py-3 rounded-lg text-white font-bold text-lg ${
            Object.keys(answers).length === quiz.questions.length
              ? 'bg-blue-600 hover:bg-blue-700'
              : 'bg-gray-400 cursor-not-allowed'
          }`}
        >
          Submit Quiz
        </button>
      </div>
    </div>
  );
}

export default Quiz;
