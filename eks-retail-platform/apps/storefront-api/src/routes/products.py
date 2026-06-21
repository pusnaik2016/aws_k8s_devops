"""Product catalog endpoints."""
from fastapi import APIRouter, Query
from pydantic import BaseModel
from typing import Optional
import structlog

logger = structlog.get_logger()
router = APIRouter()

class Product(BaseModel):
    id: str
    name: str
    description: str
    price: float
    category: str
    in_stock: bool = True

# Sample data (would be DB-backed in production)
PRODUCTS = [
    Product(id="PRD-001", name="Wireless Headphones", description="Premium noise-cancelling headphones", price=299.99, category="electronics"),
    Product(id="PRD-002", name="Running Shoes", description="Lightweight performance running shoes", price=149.99, category="footwear"),
    Product(id="PRD-003", name="Organic Coffee Beans", description="Fair-trade single origin arabica", price=24.99, category="grocery"),
    Product(id="PRD-004", name="Smart Watch", description="Fitness tracking smartwatch with GPS", price=399.99, category="electronics"),
    Product(id="PRD-005", name="Yoga Mat", description="Eco-friendly non-slip yoga mat", price=49.99, category="fitness"),
]

@router.get("/", response_model=list[Product])
async def list_products(
    category: Optional[str] = Query(None, description="Filter by category"),
    limit: int = Query(20, ge=1, le=100),
):
    logger.info("list_products", category=category, limit=limit)
    results = PRODUCTS
    if category:
        results = [p for p in results if p.category == category]
    return results[:limit]

@router.get("/{product_id}", response_model=Product)
async def get_product(product_id: str):
    logger.info("get_product", product_id=product_id)
    for p in PRODUCTS:
        if p.id == product_id:
            return p
    return {"error": "Product not found"}, 404
