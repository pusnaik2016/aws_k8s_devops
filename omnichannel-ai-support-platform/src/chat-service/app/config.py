"""Application configuration using Pydantic Settings."""

from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    """Chat service configuration — loaded from environment variables."""

    # Application
    app_name: str = "OmniPresenseAI Chat Service"
    app_version: str = "1.0.0"
    environment: str = "development"
    debug: bool = False

    # AWS
    aws_region: str = "us-east-1"
    bedrock_model_id: str = "anthropic.claude-3-5-sonnet-20240620-v1:0"
    bedrock_embedding_model_id: str = "amazon.titan-embed-text-v2:0"

    # Database (Aurora PostgreSQL)
    database_host: str = "localhost"
    database_port: int = 5432
    database_name: str = "omnipresense"
    database_user: str = "omniadmin"
    database_password: str = ""

    # Redis (ElastiCache)
    redis_host: str = "localhost"
    redis_port: int = 6379
    redis_password: str = ""
    redis_ssl: bool = False
    redis_cache_ttl: int = 3600  # 1 hour LLM cache TTL

    # RAG Configuration
    rag_top_k: int = 5  # Number of context documents to retrieve
    rag_similarity_threshold: float = 0.7

    # LLM Configuration
    llm_max_tokens: int = 1024
    llm_temperature: float = 0.7
    llm_system_prompt: str = (
        "You are OmniPresenseAI, a helpful and professional customer support assistant. "
        "Use the provided context to answer customer questions accurately. "
        "If you don't know the answer, say so honestly and offer to escalate to a human agent."
    )

    class Config:
        env_prefix = "CHAT_"
        env_file = ".env"


@lru_cache()
def get_settings() -> Settings:
    return Settings()
