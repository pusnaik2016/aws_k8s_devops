"""Search endpoints."""
from fastapi import APIRouter, Query
import structlog

logger = structlog.get_logger()
router = APIRouter()

@router.get("/")
async def search_products(q: str = Query(..., min_length=2, description="Search query")):
    logger.info("search_products", query=q)
    return {"query": q, "results": [], "total": 0, "message": "Search powered by OpenSearch"}
