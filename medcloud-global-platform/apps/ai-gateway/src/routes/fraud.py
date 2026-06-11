"""
Fraud Detection API — Real-time scoring via Vertex AI.

Uses a TabNet model trained on BigQuery transaction features
to detect fraudulent orders. Only processes de-identified data
(tokenized customer IDs, no PHI/PII).
"""

import structlog
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import Optional
from google.cloud import aiplatform
from prometheus_client import Counter, Histogram

from src.config import settings

logger = structlog.get_logger()
router = APIRouter()

# ─── Prometheus Metrics ─────────────────────────────────────────────────
FRAUD_REQUESTS = Counter(
    "fraud_detection_requests_total",
    "Total fraud detection requests",
    ["result"],
)
FRAUD_LATENCY = Histogram(
    "fraud_detection_latency_seconds",
    "Fraud detection inference latency",
)


# ─── Request / Response Models ──────────────────────────────────────────
class FraudCheckRequest(BaseModel):
    """Input features for fraud detection model."""

    customer_id: str = Field(..., description="Tokenized customer ID (FPE)")
    order_amount: float = Field(..., gt=0)
    currency: str = Field(default="USD", max_length=3)
    total_orders_30d: int = Field(default=0, ge=0)
    total_spend_30d: float = Field(default=0.0, ge=0)
    avg_order_value: float = Field(default=0.0, ge=0)
    unique_products: int = Field(default=0, ge=0)
    shipping_countries: int = Field(default=1, ge=1)
    is_prescription: bool = False


class FraudCheckResponse(BaseModel):
    """Fraud detection result."""

    customer_id: str
    fraud_score: float = Field(..., ge=0.0, le=1.0)
    is_fraud: bool
    risk_level: str  # LOW, MEDIUM, HIGH, CRITICAL
    model_version: str
    recommendation: str


# ─── Endpoints ──────────────────────────────────────────────────────────
@router.post("/check", response_model=FraudCheckResponse)
@FRAUD_LATENCY.time()
async def check_fraud(request: FraudCheckRequest):
    """
    Score an order for fraud risk using Vertex AI endpoint.
    Input: de-identified transaction features.
    Output: fraud score (0-1), risk level, action recommendation.
    """
    logger.info(
        "fraud_check_requested",
        customer_id=request.customer_id,
        order_amount=request.order_amount,
    )

    try:
        # Prepare feature vector for model
        features = [
            request.order_amount,
            request.total_orders_30d,
            request.total_spend_30d,
            request.avg_order_value,
            request.unique_products,
            request.shipping_countries,
            float(request.is_prescription),
        ]

        # Call Vertex AI endpoint
        endpoint = aiplatform.Endpoint(settings.VERTEX_AI_ENDPOINT_FRAUD)
        prediction = endpoint.predict(instances=[features])

        fraud_score = float(prediction.predictions[0])

        # Determine risk level
        if fraud_score >= 0.9:
            risk_level, recommendation = "CRITICAL", "BLOCK — Manual review required"
        elif fraud_score >= 0.7:
            risk_level, recommendation = "HIGH", "HOLD — Additional verification needed"
        elif fraud_score >= 0.4:
            risk_level, recommendation = "MEDIUM", "FLAG — Monitor closely"
        else:
            risk_level, recommendation = "LOW", "APPROVE — Normal transaction"

        result = "fraud" if fraud_score >= 0.7 else "legitimate"
        FRAUD_REQUESTS.labels(result=result).inc()

        response = FraudCheckResponse(
            customer_id=request.customer_id,
            fraud_score=round(fraud_score, 4),
            is_fraud=fraud_score >= 0.7,
            risk_level=risk_level,
            model_version="tabnet-v2.1",
            recommendation=recommendation,
        )

        logger.info(
            "fraud_check_completed",
            customer_id=request.customer_id,
            fraud_score=fraud_score,
            risk_level=risk_level,
        )

        return response

    except Exception as e:
        logger.error("fraud_check_failed", error=str(e))
        FRAUD_REQUESTS.labels(result="error").inc()
        raise HTTPException(status_code=503, detail=f"Fraud detection unavailable: {str(e)}")
