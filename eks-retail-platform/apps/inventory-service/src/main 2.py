"""Inventory Service — Stock Management."""
import os, signal, sys, structlog
from fastapi import FastAPI
from contextlib import asynccontextmanager

structlog.configure(processors=[structlog.processors.TimeStamper(fmt="iso"), structlog.processors.add_log_level, structlog.processors.JSONRenderer()], logger_factory=structlog.PrintLoggerFactory())
logger = structlog.get_logger()

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("inventory_service_starting")
    yield

app = FastAPI(title="Inventory Service", version="1.0.0", lifespan=lifespan)

from routes.health import router as health_router
app.include_router(health_router, prefix="/health")

INVENTORY = {"PRD-001": 150, "PRD-002": 80, "PRD-003": 500, "PRD-004": 30, "PRD-005": 200}

@app.get("/api/inventory/{product_id}")
async def get_stock(product_id: str):
    stock = INVENTORY.get(product_id, 0)
    logger.info("check_stock", product_id=product_id, stock=stock)
    return {"product_id": product_id, "quantity": stock, "in_stock": stock > 0}

@app.post("/api/inventory/{product_id}/reserve")
async def reserve_stock(product_id: str, quantity: int = 1):
    current = INVENTORY.get(product_id, 0)
    if current >= quantity:
        INVENTORY[product_id] = current - quantity
        logger.info("stock_reserved", product_id=product_id, quantity=quantity)
        return {"reserved": True, "remaining": INVENTORY[product_id]}
    return {"reserved": False, "remaining": current}

def handle_sigterm(*args):
    sys.exit(0)
signal.signal(signal.SIGTERM, handle_sigterm)
