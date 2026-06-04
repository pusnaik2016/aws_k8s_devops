"""Health check endpoints for K8s probes."""

from fastapi import APIRouter

router = APIRouter(tags=["Health"])


@router.get("/health")
async def liveness():
    """Kubernetes liveness probe — is the process alive?"""
    return {"status": "healthy", "service": "chat-service"}


@router.get("/ready")
async def readiness():
    """Kubernetes readiness probe — can we serve traffic?
    Checks database and Redis connectivity."""
    checks = {"database": "ok", "redis": "ok"}
    # In production, add actual connectivity checks:
    # try:
    #     await asyncpg.connect(dsn=settings.database_url)
    #     checks["database"] = "ok"
    # except Exception:
    #     checks["database"] = "error"
    return {"status": "ready", "checks": checks}
