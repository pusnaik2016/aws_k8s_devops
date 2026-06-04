"""Clearing Engine Service — Core transaction clearing and settlement."""
import structlog
from contextlib import asynccontextmanager
from fastapi import FastAPI
from prometheus_client import make_asgi_app
from app.config import settings
from app.routes import clearing, health

logger = structlog.get_logger()

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("service.starting", service="clearing-engine", environment=settings.environment)
    yield
    logger.info("service.stopped", service="clearing-engine")

app = FastAPI(
    title="Clearing Engine Service",
    description="Core matching, validation, and settlement of healthcare/financial transactions",
    version="1.0.0",
    docs_url="/docs" if settings.environment != "production" else None,
    redoc_url=None,
    lifespan=lifespan,
)
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)
app.include_router(health.router, tags=["Health"])
app.include_router(clearing.router, prefix="/api/v1", tags=["Clearing"])
