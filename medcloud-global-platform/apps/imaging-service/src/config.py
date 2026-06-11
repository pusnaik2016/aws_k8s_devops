"""Imaging service configuration."""

from pydantic_settings import BaseSettings
from typing import List


class Settings(BaseSettings):
    ENVIRONMENT: str = "dev"
    LOG_LEVEL: str = "INFO"
    ALLOWED_ORIGINS: List[str] = ["https://medcloud.example.com"]

    # Azure Blob Storage
    AZURE_STORAGE_ACCOUNT: str = "medcloudimaging"
    AZURE_STORAGE_CONTAINER: str = "dicom-images"
    AZURE_STORAGE_CONNECTION_STRING: str = ""

    # Azure AI Vision
    AZURE_AI_VISION_ENDPOINT: str = ""
    AZURE_AI_VISION_KEY: str = ""

    # Azure Key Vault
    AZURE_KEY_VAULT_URL: str = ""

    # Security
    JWT_ISSUER: str = ""
    JWT_AUDIENCE: str = "imaging-service"

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
