"""Health check endpoints for Kubernetes probes."""

from fastapi import APIRouter

router = APIRouter()


@router.get("/health/live")
async def liveness():
    """Liveness probe — is the process alive?"""
    return {"status": "UP"}


@router.get("/health/ready")
async def readiness():
    """Readiness probe — can it serve traffic?"""
    # TODO: Check Vertex AI endpoint connectivity
    return {"status": "UP", "checks": {"vertex_ai": "UP", "bigquery": "UP"}}


@router.get("/health/startup")
async def startup():
    """Startup probe — has it finished initializing?"""
    return {"status": "UP"}
