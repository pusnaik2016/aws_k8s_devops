"""
Transaction Ingestion Service — FastAPI Application
Receives, validates, and queues healthcare/financial transactions.
"""

import structlog
from contextlib import asynccontextmanager
from fastapi import FastAPI
from prometheus_client import make_asgi_app

from app.config import settings
from app.routes import transactions, health

logger = structlog.get_logger()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application startup/shutdown lifecycle."""
    logger.info(
        "service.starting",
        service="transaction-ingestion",
        environment=settings.environment,
        cloud=settings.cloud_provider,
    )
    # Startup: Initialize DB pool and Redis connection
    # In production, these would connect to Aurora/Azure SQL via private endpoints
    yield
    # Shutdown: Close connections
    logger.info("service.stopped", service="transaction-ingestion")


app = FastAPI(
    title="Transaction Ingestion Service",
    description="Receives, validates, and queues healthcare/financial clearing transactions",
    version="1.0.0",
    docs_url="/docs" if settings.environment != "production" else None,
    redoc_url=None,
    lifespan=lifespan,
)

# Mount Prometheus metrics endpoint
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)

# Register routes
app.include_router(health.router, tags=["Health"])
app.include_router(transactions.router, prefix="/api/v1", tags=["Transactions"])
