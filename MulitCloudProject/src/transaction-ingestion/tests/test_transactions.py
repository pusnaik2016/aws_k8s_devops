"""Tests for transaction ingestion service."""
import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "alive"


def test_readiness():
    response = client.get("/ready")
    assert response.status_code == 200
    assert response.json()["status"] == "ready"


def test_ingest_transaction():
    payload = {
        "transaction_type": "medical_claim",
        "amount_cents": 150000,
        "currency": "USD",
        "payer_id": "PAYER-001",
        "payee_id": "PROVIDER-042",
    }
    response = client.post("/api/v1/transactions", json=payload)
    assert response.status_code == 201
    data = response.json()
    assert data["status"] == "accepted"
    assert "transaction_id" in data


def test_ingest_invalid_currency():
    payload = {
        "transaction_type": "payment",
        "amount_cents": 100,
        "currency": "invalid",
        "payer_id": "P1",
        "payee_id": "P2",
    }
    response = client.post("/api/v1/transactions", json=payload)
    assert response.status_code == 422


def test_get_transaction():
    response = client.get("/api/v1/transactions/test-id-123")
    assert response.status_code == 200
    assert response.json()["transaction_id"] == "test-id-123"


def test_batch_ingest():
    payload = {
        "transactions": [
            {"transaction_type": "payment", "amount_cents": 5000, "currency": "USD", "payer_id": "P1", "payee_id": "P2"},
            {"transaction_type": "refund", "amount_cents": 2000, "currency": "EUR", "payer_id": "P3", "payee_id": "P4"},
        ]
    }
    response = client.post("/api/v1/transactions/batch", json=payload)
    assert response.status_code == 202
    assert response.json()["accepted"] == 2
