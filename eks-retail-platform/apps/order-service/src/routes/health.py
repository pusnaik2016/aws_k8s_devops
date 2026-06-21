"""Health check endpoints — consistent across all services."""
from fastapi import APIRouter

router = APIRouter()

@router.get("/live")
async def liveness():
    return {"status": "alive"}

@router.get("/ready")
async def readiness():
    return {"status": "ready"}

@router.get("/startup")
async def startup():
    return {"status": "started"}
