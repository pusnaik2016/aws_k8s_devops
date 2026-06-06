"""Extended unit tests for analytics service."""
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.config import Settings, get_settings

client = TestClient(app)


class TestHealthEndpoints:
    """Test K8s health probe endpoints."""

    def test_health_returns_200(self):
        response = client.get("/health")
        assert response.status_code == 200

    def test_health_service_name(self):
        response = client.get("/health")
        assert response.json()["service"] == "analytics-service"

    def test_health_status_healthy(self):
        response = client.get("/health")
        assert response.json()["status"] == "healthy"

    def test_readiness_returns_200(self):
        response = client.get("/ready")
        assert response.status_code == 200

    def test_readiness_checks_present(self):
        response = client.get("/ready")
        data = response.json()
        assert "checks" in data
        assert "database" in data["checks"]
        assert "redis" in data["checks"]
        assert "s3" in data["checks"]


class TestMetricsEndpoint:
    """Test analytics metrics endpoint."""

    def test_metrics_returns_200(self):
        response = client.get("/api/v1/analytics/metrics")
        assert response.status_code == 200

    def test_metrics_has_total_conversations(self):
        response = client.get("/api/v1/analytics/metrics")
        assert "total_conversations" in response.json()

    def test_metrics_has_sentiment_distribution(self):
        response = client.get("/api/v1/analytics/metrics")
        assert "sentiment_distribution" in response.json()


class TestTranscriptEndpoint:
    """Test transcript retrieval endpoint."""

    def test_transcript_not_found(self):
        response = client.get("/api/v1/analytics/transcripts/nonexistent-id")
        assert response.status_code == 404

    def test_transcript_not_found_detail(self):
        response = client.get("/api/v1/analytics/transcripts/abc-123")
        assert "not found" in response.json()["detail"].lower()


class TestSentimentEndpoint:
    """Test sentiment analysis endpoint."""

    def test_sentiment_positive(self):
        response = client.post(
            "/api/v1/analytics/sentiment",
            json={"message": "I love your product! Great service!", "session_id": "test-1"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["sentiment"] in ["positive", "negative", "neutral"]
        assert 0.0 <= data["score"] <= 1.0

    def test_sentiment_response_fields(self):
        response = client.post(
            "/api/v1/analytics/sentiment",
            json={"message": "This is terrible", "session_id": "test-2"},
        )
        data = response.json()
        assert "sentiment" in data
        assert "score" in data
        assert "topics" in data
        assert "escalation_recommended" in data

    def test_sentiment_missing_message(self):
        response = client.post("/api/v1/analytics/sentiment", json={})
        assert response.status_code == 422  # Validation error

    def test_sentiment_empty_message(self):
        response = client.post(
            "/api/v1/analytics/sentiment",
            json={"message": ""},
        )
        # Should still return a result (empty string is valid)
        assert response.status_code == 200

    def test_sentiment_escalation_on_low_score(self):
        """Verify escalation recommendation logic: score < 0.3 = escalate."""
        response = client.post(
            "/api/v1/analytics/sentiment",
            json={"message": "This is frustrating", "session_id": "test-3"},
        )
        data = response.json()
        if data["score"] < 0.3:
            assert data["escalation_recommended"] is True


class TestAnalyticsConfig:
    """Test analytics service configuration."""

    def test_config_app_name(self):
        s = Settings()
        assert "Analytics" in s.app_name

    def test_config_s3_bucket(self):
        s = Settings()
        assert "transcripts" in s.s3_transcripts_bucket

    def test_config_sentiment_queue(self):
        s = Settings()
        assert "analytics" in s.sentiment_queue

    def test_config_cached(self):
        s1 = get_settings()
        s2 = get_settings()
        assert s1 is s2

    def test_config_bedrock_model_is_claude(self):
        s = Settings()
        assert "claude" in s.bedrock_model_id.lower()
