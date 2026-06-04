"""
Pydantic models for transaction data structures.
"""

from datetime import datetime
from typing import List, Optional
from enum import Enum

from pydantic import BaseModel, Field


class TransactionType(str, Enum):
    MEDICAL_CLAIM = "medical_claim"
    PHARMACY_CLAIM = "pharmacy_claim"
    PAYMENT = "payment"
    REFUND = "refund"
    ADJUSTMENT = "adjustment"


class TransactionRequest(BaseModel):
    """Incoming transaction request."""

    transaction_type: TransactionType
    amount_cents: int = Field(..., gt=0, description="Amount in cents")
    currency: str = Field(default="USD", pattern="^[A-Z]{3}$")
    payer_id: str = Field(..., min_length=1, max_length=64)
    payee_id: str = Field(..., min_length=1, max_length=64)
    reference_number: Optional[str] = None
    idempotency_key: Optional[str] = Field(
        None, description="Client-provided deduplication key"
    )
    metadata: Optional[dict] = None

    model_config = {"json_schema_extra": {
        "example": {
            "transaction_type": "medical_claim",
            "amount_cents": 150000,
            "currency": "USD",
            "payer_id": "PAYER-001",
            "payee_id": "PROVIDER-042",
            "reference_number": "CLM-2026-00001",
        }
    }}


class TransactionResponse(BaseModel):
    """Transaction response with status."""

    transaction_id: str
    status: str
    received_at: datetime
    message: str


class TransactionBatchRequest(BaseModel):
    """Batch transaction request."""

    transactions: List[TransactionRequest] = Field(
        ..., min_length=1, max_length=100
    )


class TransactionBatchResponse(BaseModel):
    """Batch transaction response."""

    batch_id: str
    accepted: int
    rejected: int
    status: str
