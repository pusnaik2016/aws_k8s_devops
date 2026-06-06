"""Unit tests for chat service configuration."""
import pytest
from app.config import Settings, get_settings


class TestSettings:
    """Test configuration defaults and validation."""

    def test_default_app_name(self):
        s = Settings()
        assert s.app_name == "OmniPresenseAI Chat Service"

    def test_default_version(self):
        s = Settings()
        assert s.app_version == "1.0.0"

    def test_default_environment(self):
        s = Settings()
        assert s.environment == "development"

    def test_default_aws_region(self):
        s = Settings()
        assert s.aws_region == "us-east-1"

    def test_bedrock_model_id_is_claude(self):
        """Verify we're using Claude 3.5 Sonnet (ADR-003)."""
        s = Settings()
        assert "claude" in s.bedrock_model_id.lower()
        assert "sonnet" in s.bedrock_model_id.lower()

    def test_embedding_model_is_titan(self):
        """Verify we're using Titan Embeddings (ADR-003)."""
        s = Settings()
        assert "titan" in s.bedrock_embedding_model_id.lower()

    def test_rag_top_k_default(self):
        s = Settings()
        assert s.rag_top_k == 5

    def test_rag_similarity_threshold_range(self):
        s = Settings()
        assert 0.0 <= s.rag_similarity_threshold <= 1.0

    def test_llm_temperature_range(self):
        s = Settings()
        assert 0.0 <= s.llm_temperature <= 1.0

    def test_cache_ttl_positive(self):
        s = Settings()
        assert s.redis_cache_ttl > 0

    def test_system_prompt_contains_support_context(self):
        """Ensure system prompt frames the AI as customer support."""
        s = Settings()
        assert "customer support" in s.llm_system_prompt.lower()

    def test_system_prompt_has_escalation_instruction(self):
        """Ensure system prompt instructs escalation when uncertain."""
        s = Settings()
        assert "escalate" in s.llm_system_prompt.lower() or "human" in s.llm_system_prompt.lower()

    def test_get_settings_cached(self):
        """Verify Settings is cached via lru_cache."""
        s1 = get_settings()
        s2 = get_settings()
        assert s1 is s2

    def test_database_defaults(self):
        s = Settings()
        assert s.database_host == "localhost"
        assert s.database_port == 5432
        assert s.database_name == "omnipresense"

    def test_redis_defaults(self):
        s = Settings()
        assert s.redis_host == "localhost"
        assert s.redis_port == 6379
        assert s.redis_ssl is False
