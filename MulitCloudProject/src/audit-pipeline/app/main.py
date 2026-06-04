"""Audit Pipeline Service — Compliance audit event streaming."""
import structlog
from contextlib import asynccontextmanager
from fastapi import FastAPI
from prometheus_client import make_asgi_app
from app.config import settings
from app.routes import audit, health

logger = structlog.get_logger()

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("service.starting", service="audit-pipeline", environment=settings.environment)
    yield
    logger.info("service.stopped", service="audit-pipeline")

app = FastAPI(
    title="Audit Pipeline Service",
    description="Streams compliance audit events to BigQuery, Aurora, and AlloyDB",
    version="1.0.0",
    docs_url="/docs" if settings.environment != "production" else None,
    redoc_url=None,
    lifespan=lifespan,
)
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)
app.include_router(health.router, tags=["Health"])
app.include_router(audit.router, prefix="/api/v1", tags=["Audit"])
