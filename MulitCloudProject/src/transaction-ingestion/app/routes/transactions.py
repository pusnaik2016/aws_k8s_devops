"""
Transaction routes — Ingest, validate, and queue transactions.
"""

import uuid
from datetime import datetime, timezone
from typing import List

import structlog
from fastapi import APIRouter, HTTPException, status
from prometheus_client import Counter, Histogram

from app.models.transaction import (
    TransactionRequest,
    TransactionResponse,
    TransactionBatchRequest,
    TransactionBatchResponse,
)

logger = structlog.get_logger()
router = APIRouter()

# Prometheus metrics
TRANSACTIONS_RECEIVED = Counter(
    "transactions_received_total",
    "Total transactions received",
    ["transaction_type", "status"],
)
TRANSACTION_LATENCY = Histogram(
    "transaction_processing_seconds",
    "Transaction processing latency",
    ["transaction_type"],
)


@router.post(
    "/transactions",
    response_model=TransactionResponse,
    status_code=status.HTTP_201_CREATED,
)
async def ingest_transaction(request: TransactionRequest):
    """
    Ingest a single healthcare/financial transaction.

    - Validates schema and business rules
    - Checks for duplicates via Redis cache
    - Persists to Aurora PostgreSQL / Azure SQL
    - Returns transaction ID for tracking
    """
    transaction_id = str(uuid.uuid4())

    with TRANSACTION_LATENCY.labels(
        transaction_type=request.transaction_type
    ).time():
        logger.info(
            "transaction.received",
            transaction_id=transaction_id,
            transaction_type=request.transaction_type,
            amount_cents=request.amount_cents,
            currency=request.currency,
        )

        # TODO: In production implementation:
        # 1. Check Redis for duplicate (idempotency key)
        # 2. Validate against business rules
        # 3. Persist to database
        # 4. Publish to clearing queue

        TRANSACTIONS_RECEIVED.labels(
            transaction_type=request.transaction_type,
            status="accepted",
        ).inc()

    return TransactionResponse(
        transaction_id=transaction_id,
        status="accepted",
        received_at=datetime.now(timezone.utc),
        message="Transaction queued for clearing",
    )


@router.post(
    "/transactions/batch",
    response_model=TransactionBatchResponse,
    status_code=status.HTTP_202_ACCEPTED,
)
async def ingest_batch(request: TransactionBatchRequest):
    """Ingest a batch of transactions (up to 100 per request)."""
    if len(request.transactions) > 100:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Batch size exceeds maximum of 100 transactions",
        )

    batch_id = str(uuid.uuid4())
    logger.info(
        "batch.received",
        batch_id=batch_id,
        count=len(request.transactions),
    )

    return TransactionBatchResponse(
        batch_id=batch_id,
        accepted=len(request.transactions),
        rejected=0,
        status="processing",
    )


@router.get(
    "/transactions/{transaction_id}",
    response_model=TransactionResponse,
)
async def get_transaction(transaction_id: str):
    """Retrieve transaction status by ID."""
    # TODO: Query database for transaction status
    logger.info("transaction.query", transaction_id=transaction_id)

    return TransactionResponse(
        transaction_id=transaction_id,
        status="cleared",
        received_at=datetime.now(timezone.utc),
        message="Transaction has been cleared successfully",
    )
