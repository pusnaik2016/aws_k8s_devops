"""Notification Service — SQS Consumer (KEDA-scaled)."""
import os, json, signal, sys, boto3, structlog
from fastapi import FastAPI
from contextlib import asynccontextmanager

structlog.configure(processors=[structlog.processors.TimeStamper(fmt="iso"), structlog.processors.add_log_level, structlog.processors.JSONRenderer()], logger_factory=structlog.PrintLoggerFactory())
logger = structlog.get_logger()

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("notification_service_starting")
    yield

app = FastAPI(title="Notification Service", version="1.0.0", lifespan=lifespan)

from routes.health import router as health_router
app.include_router(health_router, prefix="/health")

@app.post("/api/notifications/send")
async def send_notification(notification: dict):
    channel = notification.get("channel", "email")
    recipient = notification.get("recipient", "unknown")
    # GDPR: redact PII from logs
    logger.info("notification_sent", channel=channel, recipient_hash=hash(recipient), event=notification.get("event"))
    return {"notification_id": f"NTF-{id(notification)}", "status": "sent", "channel": channel}

@app.get("/api/notifications/status/{notification_id}")
async def get_status(notification_id: str):
    return {"notification_id": notification_id, "status": "delivered"}

def handle_sigterm(*args):
    sys.exit(0)
signal.signal(signal.SIGTERM, handle_sigterm)
