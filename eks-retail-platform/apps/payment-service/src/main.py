"""Payment Service — PCI-DSS Compliant Payment Processing."""
import os, signal, sys, structlog
from fastapi import FastAPI, Request
from contextlib import asynccontextmanager

structlog.configure(processors=[structlog.processors.TimeStamper(fmt="iso"), structlog.processors.add_log_level, structlog.processors.JSONRenderer()], logger_factory=structlog.PrintLoggerFactory())
logger = structlog.get_logger()

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("payment_service_starting", compliance="PCI-DSS")
    yield

app = FastAPI(title="Payment Service", version="1.0.0", docs_url=None, redoc_url=None, lifespan=lifespan)

# PCI-DSS: Security headers
@app.middleware("http")
async def pci_security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Strict-Transport-Security"] = "max-age=63072000; includeSubDomains; preload"
    response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    return response

from routes.health import router as health_router
app.include_router(health_router, prefix="/health")

@app.post("/api/payments/process")
async def process_payment(payment: dict):
    # PCI-DSS: Never log card numbers - only last 4 digits
    masked = f"****-****-****-{str(payment.get('card_number', '0000'))[-4:]}"
    logger.info("payment_processing", order_id=payment.get("order_id"), card_masked=masked)
    return {"payment_id": f"PAY-{id(payment)}", "status": "approved", "order_id": payment.get("order_id")}

@app.post("/api/payments/refund")
async def process_refund(refund: dict):
    logger.info("refund_processing", payment_id=refund.get("payment_id"))
    return {"refund_id": f"REF-{id(refund)}", "status": "processed"}

def handle_sigterm(*args):
    sys.exit(0)
signal.signal(signal.SIGTERM, handle_sigterm)
