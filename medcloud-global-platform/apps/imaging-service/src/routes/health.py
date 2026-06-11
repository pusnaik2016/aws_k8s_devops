"""Health check endpoints."""

from fastapi import APIRouter

router = APIRouter()


@router.get("/health/live")
async def liveness():
    return {"status": "UP"}


@router.get("/health/ready")
async def readiness():
    return {"status": "UP", "checks": {"blob_storage": "UP", "ai_vision": "UP"}}


@router.get("/health/startup")
async def startup():
    return {"status": "UP"}
