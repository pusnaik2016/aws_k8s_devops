"""FastAPI Analytics Service — Entry Point."""
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from app.config import get_settings
from app.routes.analytics import router as analytics_router
from app.routes.health import router as health_router

logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    logger.info(f"Starting {settings.app_name} v{settings.app_version}")
    yield
    logger.info("Shutting down Analytics Service")

app = FastAPI(
    title="OmniPresenseAI Analytics Service",
    description="Real-time sentiment analytics and conversation metrics",
    version="1.0.0",
    lifespan=lifespan,
)
app.include_router(health_router)
app.include_router(analytics_router, prefix="/api/v1")
