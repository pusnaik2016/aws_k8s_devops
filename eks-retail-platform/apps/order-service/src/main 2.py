"""Order Service — SQS Queue Consumer (KEDA-scaled)."""
import os, json, signal, sys, boto3, structlog
from fastapi import FastAPI
from contextlib import asynccontextmanager

structlog.configure(processors=[structlog.processors.TimeStamper(fmt="iso"), structlog.processors.add_log_level, structlog.processors.JSONRenderer()], logger_factory=structlog.PrintLoggerFactory())
logger = structlog.get_logger()

sqs = boto3.client("sqs", region_name=os.getenv("AWS_REGION", "us-east-1"))
sns = boto3.client("sns", region_name=os.getenv("AWS_REGION", "us-east-1"))

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("order_service_starting")
    yield
    logger.info("order_service_stopping")

app = FastAPI(title="Order Service", version="1.0.0", lifespan=lifespan)

from routes.health import router as health_router
app.include_router(health_router, prefix="/health")

@app.post("/api/orders")
async def create_order(order: dict):
    order_id = f"ORD-{id(order)}"
    logger.info("order_created", order_id=order_id)
    # Publish to SNS for downstream processing
    try:
        sns.publish(TopicArn=os.getenv("SNS_NOTIFICATION_TOPIC", ""), Message=json.dumps({"order_id": order_id, "event": "order_created", **order}), MessageGroupId="orders")
    except Exception as e:
        logger.error("sns_publish_failed", error=str(e))
    return {"order_id": order_id, "status": "created"}

@app.get("/api/orders/{order_id}")
async def get_order(order_id: str):
    logger.info("get_order", order_id=order_id)
    return {"order_id": order_id, "status": "processing", "items": []}

def handle_sigterm(*args):
    sys.exit(0)
signal.signal(signal.SIGTERM, handle_sigterm)
