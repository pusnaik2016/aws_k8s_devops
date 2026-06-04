"""Analytics service configuration."""
from pydantic_settings import BaseSettings
from functools import lru_cache

class Settings(BaseSettings):
    app_name: str = "OmniPresenseAI Analytics Service"
    app_version: str = "1.0.0"
    environment: str = "development"
    aws_region: str = "us-east-1"
    bedrock_model_id: str = "anthropic.claude-3-5-sonnet-20240620-v1:0"
    database_host: str = "localhost"
    database_port: int = 5432
    database_name: str = "omnipresense"
    database_user: str = "omniadmin"
    database_password: str = ""
    redis_host: str = "localhost"
    redis_port: int = 6379
    redis_password: str = ""
    redis_ssl: bool = False
    s3_transcripts_bucket: str = "omnipresense-ai-prod-transcripts"
    sentiment_queue: str = "analytics:sentiment_queue"

    class Config:
        env_prefix = "ANALYTICS_"
        env_file = ".env"

@lru_cache()
def get_settings() -> Settings:
    return Settings()
