"""AI Gateway configuration — loaded from environment variables."""

from pydantic_settings import BaseSettings
from typing import List


class Settings(BaseSettings):
    """Application settings from environment variables."""

    # Application
    ENVIRONMENT: str = "dev"
    LOG_LEVEL: str = "INFO"
    ALLOWED_ORIGINS: List[str] = ["https://medcloud.example.com"]

    # GCP
    GCP_PROJECT_ID: str = "medcloud-global-dev"
    GCP_REGION: str = "us-central1"

    # Vertex AI
    VERTEX_AI_ENDPOINT_FRAUD: str = ""
    VERTEX_AI_ENDPOINT_RECOMMEND: str = ""

    # BigQuery
    BIGQUERY_DATASET: str = "ecommerce_transactions"

    # Cloud DLP
    DLP_TEMPLATE_ID: str = "medcloud-phi-deidentify"

    # Security
    JWT_ISSUER: str = ""
    JWT_AUDIENCE: str = "ai-gateway"

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
