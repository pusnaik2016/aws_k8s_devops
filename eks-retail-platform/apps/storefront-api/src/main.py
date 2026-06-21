"""
Storefront API — Product Catalog & Search
Scaling: Native HPA with scale-to-zero (K8s 1.36+)
"""
import os
import signal
import sys
import structlog
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
from routes.health import router as health_router
from routes.products import router as products_router
from routes.search import router as search_router

# Structured JSON logging (FluentBit compatible)
structlog.configure(
    processors=[
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.add_log_level,
        structlog.processors.JSONRenderer()
    ],
    logger_factory=structlog.PrintLoggerFactory(),
)
logger = structlog.get_logger()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Graceful startup/shutdown for compliance."""
    logger.info("storefront_api_starting", version="1.0.0")
    yield
    logger.info("storefront_api_shutting_down")


app = FastAPI(
    title="Storefront API",
    description="Product catalog and search service for EKS Retail Platform",
    version="1.0.0",
    docs_url="/docs" if os.getenv("APP_ENV") != "production" else None,
    lifespan=lifespan,
)

# Security headers middleware
@app.middleware("http")
async def security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["Cache-Control"] = "no-store"
    response.headers["Content-Security-Policy"] = "default-src 'none'"
    return response

# CORS (restricted in production)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://retail.example.com"] if os.getenv("APP_ENV") == "production" else ["*"],
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

# Routes
app.include_router(health_router, prefix="/health", tags=["Health"])
app.include_router(products_router, prefix="/api/products", tags=["Products"])
app.include_router(search_router, prefix="/api/search", tags=["Search"])


# Graceful shutdown handler
def handle_sigterm(*args):
    logger.info("sigterm_received", msg="Graceful shutdown initiated")
    sys.exit(0)

signal.signal(signal.SIGTERM, handle_sigterm)
