"""
AgentCore Memory — Memory Writer Lambda
==========================================
Handles Bedrock Agent action group events for the save_to_long_term_memory
function. Writes facts to S3, triggers KB ingestion, and records events
in DynamoDB.

Environment Variables:
    MEMORY_BUCKET        — S3 bucket for memory markdown documents
    DYNAMODB_TABLE       — DynamoDB table for session audit trail
    KNOWLEDGE_BASE_ID    — Bedrock Knowledge Base ID
    DATA_SOURCE_ID       — KB data source ID
    CONFIDENCE_THRESHOLD — Minimum confidence to persist (default: 0.7)
"""

import json
import os
import uuid
import time
import logging
from datetime import datetime, timezone

import boto3

# ── Configuration ────────────────────────────────────────────────────────────

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")
bedrock_agent = boto3.client("bedrock-agent")

MEMORY_BUCKET = os.environ.get("MEMORY_BUCKET", "")
DYNAMODB_TABLE = os.environ.get("DYNAMODB_TABLE", "")
KNOWLEDGE_BASE_ID = os.environ.get("KNOWLEDGE_BASE_ID", "")
DATA_SOURCE_ID = os.environ.get("DATA_SOURCE_ID", "")
CONFIDENCE_THRESHOLD = float(os.environ.get("CONFIDENCE_THRESHOLD", "0.7"))

VALID_CATEGORIES = {"preference", "project_context", "decision", "user_profile"}


# ── Lambda Handler ───────────────────────────────────────────────────────────

def lambda_handler(event, context):
    """
    Handle Bedrock Agent action group events.
    
    The event format for function-based action groups:
    {
        "function": "save_to_long_term_memory",
        "sessionId": "...",
        "parameters": [
            {"name": "fact", "value": "..."},
            {"name": "category", "value": "preference"},
            {"name": "confidence", "value": "0.9"}
        ]
    }
    """
    function_name = event.get("function", "save_to_long_term_memory")
    session_id = event.get("sessionId", "unknown")
    parameters = {p["name"]: p["value"] for p in event.get("parameters", [])}

    logger.info(
        "MEMORY_REQUEST session_id=%s function=%s params=%s",
        session_id, function_name, json.dumps(parameters)
    )

    try:
        result = _process_memory_save(session_id, parameters)
    except Exception as e:
        logger.error("MEMORY_ERROR session_id=%s error=%s", session_id, str(e))
        result = {"status": "error", "message": str(e)}

    # Return in Bedrock action group response format
    return {
        "messageVersion": "1.0",
        "response": {
            "actionGroup": "MemoryActions",
            "function": function_name,
            "functionResponse": {
                "responseBody": {
                    "TEXT": {"body": json.dumps(result)}
                }
            }
        }
    }


# ── Core Logic ───────────────────────────────────────────────────────────────

def _process_memory_save(session_id: str, parameters: dict) -> dict:
    """Process a memory save request with confidence gating."""

    fact = parameters.get("fact", "").strip()
    category = parameters.get("category", "general").strip().lower()
    confidence = float(parameters.get("confidence", 0))

    if not fact:
        return {"status": "error", "message": "Empty fact — nothing to save"}

    if category not in VALID_CATEGORIES:
        category = "general"

    # ── Confidence Gate ──
    if confidence < CONFIDENCE_THRESHOLD:
        logger.info(
            "MEMORY_SKIPPED session_id=%s confidence=%.2f threshold=%.2f fact=%s",
            session_id, confidence, CONFIDENCE_THRESHOLD, fact[:80]
        )
        return {
            "status": "skipped",
            "reason": f"Confidence {confidence:.2f} below threshold {CONFIDENCE_THRESHOLD}",
            "fact": fact[:100],
        }

    # ── Generate document ──
    doc_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc)
    timestamp_iso = now.strftime("%Y-%m-%dT%H:%M:%S+00:00")
    timestamp_ms = int(now.timestamp() * 1000)

    markdown_doc = _build_markdown(doc_id, session_id, category, confidence, timestamp_iso, fact)
    s3_key = f"memories/{category}/{doc_id}.md"

    # ── Write to S3 ──
    s3.put_object(
        Bucket=MEMORY_BUCKET,
        Key=s3_key,
        Body=markdown_doc.encode("utf-8"),
        ContentType="text/markdown",
        Metadata={
            "session_id": session_id,
            "category": category,
            "confidence": str(confidence),
        }
    )

    # ── Record in DynamoDB ──
    table = dynamodb.Table(DYNAMODB_TABLE)
    ttl_seconds = int(now.timestamp()) + (90 * 86400)  # 90-day TTL

    table.put_item(Item={
        "session_id": session_id,
        "timestamp_ms": timestamp_ms,
        "document_id": doc_id,
        "s3_key": s3_key,
        "category": category,
        "confidence": str(confidence),
        "fact_preview": fact[:200],
        "ttl": ttl_seconds,
    })

    # ── Trigger KB Ingestion ──
    ingestion_job_id = _trigger_ingestion()

    logger.info(
        "MEMORY_SAVED session_id=%s doc_id=%s category=%s confidence=%.2f "
        "s3_key=%s ingestion_job=%s",
        session_id, doc_id, category, confidence, s3_key,
        ingestion_job_id or "N/A"
    )

    return {
        "status": "saved",
        "document_id": doc_id,
        "document_key": s3_key,
        "category": category,
        "confidence": confidence,
        "ingestion_job_id": ingestion_job_id,
    }


# ── Helpers ──────────────────────────────────────────────────────────────────

def _build_markdown(doc_id, session_id, category, confidence, timestamp, fact):
    """Build a YAML-frontmatter markdown document for the memory fact."""
    return f"""---
id: {doc_id}
session_id: {session_id}
category: {category}
confidence: {confidence}
saved_at: {timestamp}
---

# Memory: {category}

{fact}

_Saved from session {session_id} at {timestamp}_
"""


def _trigger_ingestion():
    """Start a Bedrock KB ingestion job. Returns job ID or None on failure."""
    if not KNOWLEDGE_BASE_ID or not DATA_SOURCE_ID:
        logger.warning("INGESTION_SKIPPED — KB/DS IDs not configured")
        return None

    try:
        response = bedrock_agent.start_ingestion_job(
            knowledgeBaseId=KNOWLEDGE_BASE_ID,
            dataSourceId=DATA_SOURCE_ID,
        )
        return response.get("ingestionJob", {}).get("ingestionJobId")
    except Exception as e:
        logger.error("INGESTION_ERROR error=%s", str(e))
        return None
