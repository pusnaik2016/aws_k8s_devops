"""Unit tests for chat service."""
import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_health_endpoint():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"


def test_readiness_endpoint():
    response = client.get("/ready")
    assert response.status_code == 200
    assert response.json()["status"] == "ready"


def test_chat_endpoint_missing_message():
    response = client.post("/api/v1/chat", json={})
    assert response.status_code == 422  # Validation error
