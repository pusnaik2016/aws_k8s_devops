"""
MedCloud Imaging Service — FastAPI Application.

DICOM medical image processing deployed on Azure AKS.
Uploads DICOM images to Azure Blob Storage, analyzes via
Azure AI Vision, and generates clinical reports.

Compliance: HIPAA (PHI — medical images are Protected Health Information).
"""

import structlog
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from prometheus_client import make_asgi_app

from src.routes import images, health
from src.config import settings

logger = structlog.get_logger()


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info(
        "imaging_service_starting",
        environment=settings.ENVIRONMENT,
        storage_account=settings.AZURE_STORAGE_ACCOUNT,
    )
    yield
    logger.info("imaging_service_shutting_down")


app = FastAPI(
    title="MedCloud Imaging Service",
    description="DICOM Processing — Azure AI Vision + Blob Storage",
    version="1.0.0",
    docs_url="/docs" if settings.ENVIRONMENT != "production" else None,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_methods=["GET", "POST", "DELETE"],
    allow_headers=["*"],
)

# Prometheus metrics
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)

# Routes
app.include_router(health.router, tags=["Health"])
app.include_router(images.router, prefix="/api/v1/images", tags=["Medical Imaging"])
