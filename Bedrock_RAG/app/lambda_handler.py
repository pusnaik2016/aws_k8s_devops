"""
Enterprise RAG Chatbot — Lambda Handler (Query Router)

Routes incoming queries to the appropriate generation strategy:
  - RAG: Vector search via OpenSearch → Bedrock (default)
  - CAG: Cache-augmented with prompt caching for cost reduction
  - KAG: Knowledge-augmented via entity/graph lookup
"""
import json
import logging
import os
import time
import traceback

from rag_engine import RAGEngine
from cag_engine import CAGEngine

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO")
logger = logging.getLogger()
logger.setLevel(LOG_LEVEL)

# Lazy-initialized engines (reused across warm invocations)
_rag_engine = None
_cag_engine = None


def _get_rag_engine():
    global _rag_engine
    if _rag_engine is None:
        _rag_engine = RAGEngine(
            opensearch_endpoint=os.environ["OPENSEARCH_ENDPOINT"],
            index_name=os.environ.get("INDEX_NAME", "rag-knowledge-base"),
            model_id=os.environ["BEDROCK_MODEL_ID"],
            embedding_model_id=os.environ["EMBEDDING_MODEL_ID"],
        )
    return _rag_engine


def _get_cag_engine():
    global _cag_engine
    if _cag_engine is None:
        _cag_engine = CAGEngine(
            model_id=os.environ["BEDROCK_MODEL_ID"],
            s3_bucket=os.environ["S3_BUCKET_NAME"],
        )
    return _cag_engine


# ---------------------------------------------------------------------------
# Response Helpers
# ---------------------------------------------------------------------------
def _cors_response(status_code: int, body: dict) -> dict:
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type, Authorization",
        },
        "body": json.dumps(body),
    }


# ---------------------------------------------------------------------------
# Handler
# ---------------------------------------------------------------------------
def handler(event, context):
    """
    API Gateway Lambda Proxy handler.

    POST /chat
    {
        "query": "What is our return policy?",
        "strategy": "rag",          // Optional: rag (default), cag
        "top_k": 5,                 // Optional: number of context chunks
        "conversation_id": "abc123" // Optional: for conversation history
    }

    GET /health
    Returns 200 with service status.
    """
    logger.info(f"Event: {json.dumps(event, default=str)}")

    http_method = event.get("httpMethod", "")
    path = event.get("path", "")

    # --- Health check ---
    if path == "/health" or http_method == "GET":
        return _cors_response(200, {
            "status": "healthy",
            "service": "enterprise-rag-chatbot",
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        })

    # --- Chat endpoint ---
    if http_method != "POST":
        return _cors_response(405, {"error": "Method not allowed"})

    try:
        body = json.loads(event.get("body", "{}"))
    except json.JSONDecodeError:
        return _cors_response(400, {"error": "Invalid JSON body"})

    query = body.get("query", "").strip()
    if not query:
        return _cors_response(400, {"error": "Missing 'query' field"})

    strategy = body.get("strategy", "rag").lower()
    top_k = min(int(body.get("top_k", 5)), 20)  # Cap at 20

    logger.info(f"Query: '{query}', Strategy: {strategy}, Top-K: {top_k}")

    start_time = time.time()

    try:
        if strategy == "cag":
            engine = _get_cag_engine()
            result = engine.generate(query=query)
        else:  # Default: RAG
            engine = _get_rag_engine()
            result = engine.generate(query=query, top_k=top_k)

        latency_ms = int((time.time() - start_time) * 1000)

        response = {
            "answer": result["answer"],
            "sources": result.get("sources", []),
            "strategy": strategy,
            "model": os.environ["BEDROCK_MODEL_ID"],
            "latency_ms": latency_ms,
            "token_usage": result.get("token_usage", {}),
        }

        logger.info(f"Response generated in {latency_ms}ms using {strategy}")
        return _cors_response(200, response)

    except Exception as e:
        logger.error(f"Error: {traceback.format_exc()}")
        return _cors_response(500, {
            "error": "Internal server error",
            "message": str(e) if LOG_LEVEL == "DEBUG" else "An error occurred",
        })
