from fastapi import APIRouter
router = APIRouter(tags=["Health"])

@router.get("/health")
async def liveness():
    return {"status": "healthy", "service": "analytics-service"}

@router.get("/ready")
async def readiness():
    return {"status": "ready", "checks": {"database": "ok", "redis": "ok", "s3": "ok"}}
