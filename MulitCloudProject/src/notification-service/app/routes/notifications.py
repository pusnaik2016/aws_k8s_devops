"""Notification routes — Send transaction status updates."""
import uuid
from datetime import datetime, timezone
import structlog
from fastapi import APIRouter, status
from prometheus_client import Counter

logger = structlog.get_logger()
router = APIRouter()

NOTIFICATIONS_SENT = Counter("notifications_sent_total", "Total notifications sent", ["channel", "status"])

@router.post("/notify", status_code=status.HTTP_202_ACCEPTED)
async def send_notification(transaction_id: str, channel: str = "webhook", recipient: str = None):
    """Send a transaction status notification via the specified channel."""
    notification_id = str(uuid.uuid4())
    logger.info("notification.queued", notification_id=notification_id, channel=channel, transaction_id=transaction_id)
    NOTIFICATIONS_SENT.labels(channel=channel, status="queued").inc()
    return {"notification_id": notification_id, "status": "queued", "channel": channel, "queued_at": datetime.now(timezone.utc)}

@router.get("/webhooks")
async def list_webhooks():
    """List configured webhook endpoints."""
    return {"webhooks": [], "message": "No webhooks configured — add via POST /api/v1/webhooks"}
