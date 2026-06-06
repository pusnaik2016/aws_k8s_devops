"""Notification Service — Transaction status notifications."""
import structlog
from contextlib import asynccontextmanager
from fastapi import FastAPI
from prometheus_client import make_asgi_app
from app.config import settings
from app.routes import notifications, health

logger = structlog.get_logger()

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("service.starting", service="notification-service", environment=settings.environment)
    yield
    logger.info("service.stopped", service="notification-service")

app = FastAPI(
    title="Notification Service",
    description="Sends transaction status updates via webhooks, email, and message queues",
    version="1.0.0",
    docs_url="/docs" if settings.environment != "production" else None,
    redoc_url=None,
    lifespan=lifespan,
)
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)
app.include_router(health.router, tags=["Health"])
app.include_router(notifications.router, prefix="/api/v1", tags=["Notifications"])
