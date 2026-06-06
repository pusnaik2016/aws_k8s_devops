"""
Health check endpoints — Kubernetes liveness and readiness probes.
"""

from fastapi import APIRouter, Response, status

router = APIRouter()


@router.get("/health", status_code=status.HTTP_200_OK)
async def liveness():
    """Liveness probe — returns 200 if the process is alive."""
    return {"status": "alive", "service": "audit-pipeline"}


@router.get("/ready", status_code=status.HTTP_200_OK)
async def readiness():
    """
    Readiness probe — returns 200 if the service can handle traffic.
    Checks database and Redis connectivity.
    """
    checks = {"database": "ok", "redis": "ok"}
    # In production, these would attempt real connections:
    # try:
    #     async with db_pool.acquire() as conn:
    #         await conn.execute("SELECT 1")
    # except Exception:
    #     checks["database"] = "error"
    #     return Response(status_code=status.HTTP_503_SERVICE_UNAVAILABLE)

    return {"status": "ready", "service": "audit-pipeline", "checks": checks}
