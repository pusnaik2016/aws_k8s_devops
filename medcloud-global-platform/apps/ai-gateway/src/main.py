"""
MedCloud AI Gateway — FastAPI Application.

ML inference gateway deployed on GCP GKE.
Provides fraud detection, product recommendations,
and data de-identification via Cloud DLP.

Compliance: Only processes de-identified data (no PHI/PII).
"""

import structlog
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from prometheus_client import make_asgi_app

from src.routes import fraud, recommendations, health
from src.config import settings

logger = structlog.get_logger()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application startup and shutdown events."""
    logger.info(
        "ai_gateway_starting",
        environment=settings.ENVIRONMENT,
        gcp_project=settings.GCP_PROJECT_ID,
    )
    yield
    logger.info("ai_gateway_shutting_down")


app = FastAPI(
    title="MedCloud AI Gateway",
    description="ML Inference Gateway — Fraud Detection & Recommendations",
    version="1.0.0",
    docs_url="/docs" if settings.ENVIRONMENT != "production" else None,
    lifespan=lifespan,
)

# ─── Middleware ──────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

# ─── Prometheus Metrics ─────────────────────────────────────────────────
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)

# ─── Routes ─────────────────────────────────────────────────────────────
app.include_router(health.router, tags=["Health"])
app.include_router(fraud.router, prefix="/api/v1/fraud", tags=["Fraud Detection"])
app.include_router(
    recommendations.router,
    prefix="/api/v1/recommendations",
    tags=["Recommendations"],
)
