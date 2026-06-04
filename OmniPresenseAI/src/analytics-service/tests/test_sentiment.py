"""Unit tests for analytics service."""
import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["service"] == "analytics-service"

def test_readiness():
    response = client.get("/ready")
    assert response.status_code == 200

def test_metrics_endpoint():
    response = client.get("/api/v1/analytics/metrics")
    assert response.status_code == 200
    data = response.json()
    assert "total_conversations" in data
    assert "sentiment_distribution" in data

def test_transcript_not_found():
    response = client.get("/api/v1/analytics/transcripts/nonexistent")
    assert response.status_code == 404
