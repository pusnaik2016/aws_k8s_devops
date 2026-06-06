import React, { useState, useEffect } from 'react';
import { getTopics, addQuestion, bulkUploadQuestions } from '../services/api';

function QuestionManager() {
  const [topics, setTopics] = useState([]);
  const [formData, setFormData] = useState({
    topic_slug: '',
    question_text: '',
    options: ['', '', '', ''],
    correct_answer: 0
  });
  const [csvData, setCsvData] = useState('');
  const [message, setMessage] = useState(null);
  const [activeTab, setActiveTab] = useState('single');

  useEffect(() => {
    const fetchTopics = async () => {
      try {
        const response = await getTopics();
        setTopics(response.data);
      } catch (err) {
        console.error('Error fetching topics:', err);
      }
    };
    fetchTopics();
  }, []);

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handleOptionChange = (index, value) => {
    const newOptions = [...formData.options];
    newOptions[index] = value;
    setFormData(prev => ({ ...prev, options: newOptions }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      await addQuestion(formData);
      setMessage({ type: 'success', text: 'Question added successfully!' });
      setFormData({
        topic_slug: '',
        question_text: '',
        options: ['', '', '', ''],
        correct_answer: 0
      });
    } catch (err) {
      setMessage({ type: 'error', text: `Error: ${err.response?.data?.error || err.message}` });
    }
  };

  const handleBulkUpload = async () => {
    try {
      const lines = csvData.trim().split('\n');
      const headers = lines[0].split(',');
      const questions = [];

      for (let i = 1; i < lines.length; i++) {
        const values = lines[i].split(',');
        if (values.length >= 7) {
          questions.push({
            topic_slug: values[0].trim(),
            question_text: values[1].trim(),
            options: [
              values[2].trim(),
              values[3].trim(),
              values[4].trim(),
              values[5].trim()
            ],
            correct_answer: parseInt(values[6].trim())
          });
        }
      }

      const response = await bulkUploadQuestions(questions);
      setMessage({
        type: 'success',
        text: `Bulk upload: ${response.data.success} succeeded, ${response.data.failed} failed`
      });
      setCsvData('');
    } catch (err) {
      setMessage({ type: 'error', text: `Error: ${err.response?.data?.error || err.message}` });
    }
  };

  return (
    <div className="container mx-auto p-8">
      <h1 className="text-3xl font-bold text-gray-800 mb-8">Question Management</h1>

      {message && (
        <div className={`mb-6 p-4 rounded-lg ${
          message.type === 'success' ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'
        }`}>
          {message.text}
        </div>
      )}

      <div className="mb-6">
        <div className="flex space-x-4">
          <button
            className={`px-6 py-2 rounded-lg font-semibold ${
              activeTab === 'single' ? 'bg-blue-600 text-white' : 'bg-gray-200 text-gray-700'
            }`}
            onClick={() => setActiveTab('single')}
          >
            Add Single Question
          </button>
          <button
            className={`px-6 py-2 rounded-lg font-semibold ${
              activeTab === 'bulk' ? 'bg-blue-600 text-white' : 'bg-gray-200 text-gray-700'
            }`}
            onClick={() => setActiveTab('bulk')}
          >
            Bulk Upload (CSV)
          </button>
        </div>
      </div>

      {activeTab === 'single' && (
        <div className="bg-white rounded-lg shadow-md p-6">
          <h2 className="text-xl font-bold mb-4">Add Single Question</h2>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Topic</label>
              <select
                name="topic_slug"
                value={formData.topic_slug}
                onChange={handleInputChange}
                className="w-full border rounded-lg p-2"
                required
              >
                <option value="">Select a topic</option>
                {topics.map(topic => (
                  <option key={topic.id} value={topic.id}>{topic.title}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Question</label>
              <textarea
                name="question_text"
                value={formData.question_text}
                onChange={handleInputChange}
                className="w-full border rounded-lg p-2"
                rows="3"
                required
              />
            </div>

            {formData.options.map((option, index) => (
              <div key={index}>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Option {index + 1}
                </label>
                <input
                  type="text"
                  value={option}
                  onChange={(e) => handleOptionChange(index, e.target.value)}
                  className="w-full border rounded-lg p-2"
                  required
                />
              </div>
            ))}

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Correct Answer (0-3)
              </label>
              <select
                name="correct_answer"
                value={formData.correct_answer}
                onChange={(e) => setFormData(prev => ({ ...prev, correct_answer: parseInt(e.target.value) }))}
                className="w-full border rounded-lg p-2"
              >
                {[0, 1, 2, 3].map(i => (
                  <option key={i} value={i}>Option {i + 1}</option>
                ))}
              </select>
            </div>

            <button
              type="submit"
              className="w-full bg-blue-600 text-white py-2 rounded-lg hover:bg-blue-700"
            >
              Add Question
            </button>
          </form>
        </div>
      )}

      {activeTab === 'bulk' && (
        <div className="bg-white rounded-lg shadow-md p-6">
          <h2 className="text-xl font-bold mb-4">Bulk Upload Questions (CSV)</h2>
          <p className="text-gray-600 mb-4">
            Format: topic_slug,question_text,option_1,option_2,option_3,option_4,correct_answer
          </p>
          <textarea
            value={csvData}
            onChange={(e) => setCsvData(e.target.value)}
            className="w-full border rounded-lg p-2 mb-4"
            rows="10"
            placeholder="topic_slug,question_text,option_1,option_2,option_3,option_4,correct_answer"
          />
          <button
            onClick={handleBulkUpload}
            className="w-full bg-green-600 text-white py-2 rounded-lg hover:bg-green-700"
            disabled={!csvData.trim()}
          >
            Upload Questions
          </button>
        </div>
      )}
    </div>
  );
}

export default QuestionManager;
