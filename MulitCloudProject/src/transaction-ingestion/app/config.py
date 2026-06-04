"""
Application configuration — environment-driven via Pydantic Settings.
No hardcoded secrets — all injected via K8s env vars / IRSA / Workload Identity.
"""

from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # --- Service Identity ---
    service_name: str = "transaction-ingestion"
    environment: str = "production"
    cloud_provider: str = "aws"  # aws | azure | gcp
    log_level: str = "INFO"

    # --- Database (Aurora PostgreSQL / Azure SQL) ---
    database_host: str = "localhost"
    database_port: int = 5432
    database_name: str = "clearingdb"
    database_user: str = "app_user"
    database_password: Optional[str] = None  # Injected via K8s secret
    database_ssl_mode: str = "require"
    database_pool_min: int = 5
    database_pool_max: int = 20

    # --- Redis (ElastiCache / Azure Cache) ---
    redis_host: str = "localhost"
    redis_port: int = 6379
    redis_password: Optional[str] = None
    redis_ssl: bool = True
    redis_db: int = 0

    # --- API Settings ---
    api_rate_limit: int = 1000  # requests per minute
    max_transaction_batch_size: int = 100
    request_timeout_seconds: int = 30

    # --- Observability ---
    otel_exporter_endpoint: Optional[str] = None
    enable_prometheus: bool = True

    class Config:
        env_prefix = ""
        case_sensitive = False
        env_file = ".env"


settings = Settings()
