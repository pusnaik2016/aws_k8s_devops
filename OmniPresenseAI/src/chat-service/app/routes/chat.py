"""Chat endpoints — WebSocket real-time + REST fallback."""

import json
import logging
import hashlib
from typing import Optional

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, HTTPException
from pydantic import BaseModel

from app.config import get_settings
from app.services.bedrock_client import BedrockClient
from app.services.rag_engine import RAGEngine
from app.services.cache_service import CacheService
from app.services.session_manager import SessionManager

logger = logging.getLogger(__name__)
router = APIRouter(tags=["Chat"])

# Service instances (initialized lazily)
settings = get_settings()
bedrock = BedrockClient(settings)
rag = RAGEngine(settings)
cache = CacheService(settings)
sessions = SessionManager(settings)


class ChatRequest(BaseModel):
    """REST chat request body."""
    message: str
    session_id: Optional[str] = None
    user_id: Optional[str] = "anonymous"


class ChatResponse(BaseModel):
    """Chat response body."""
    response: str
    session_id: str
    cached: bool = False
    sources: list[str] = []


@router.post("/chat", response_model=ChatResponse)
async def chat_rest(request: ChatRequest):
    """REST endpoint for chat (fallback when WebSocket unavailable)."""
    session_id = request.session_id or sessions.create_session(request.user_id)

    # Check LLM cache
    cache_key = _generate_cache_key(request.message)
    cached_response = await cache.get(cache_key)
    if cached_response:
        logger.info(f"Cache HIT for session {session_id}")
        return ChatResponse(
            response=cached_response,
            session_id=session_id,
            cached=True,
        )

    # RAG: retrieve relevant context
    context_docs = await rag.retrieve(request.message)
    sources = [doc.get("source", "") for doc in context_docs]

    # Build conversation with context
    conversation_history = await sessions.get_history(session_id)
    ai_response = await bedrock.generate_response(
        message=request.message,
        context=context_docs,
        history=conversation_history,
    )

    # Cache the response
    await cache.set(cache_key, ai_response, ttl=settings.redis_cache_ttl)

    # Update session history
    await sessions.add_message(session_id, "user", request.message)
    await sessions.add_message(session_id, "assistant", ai_response)

    # Push to analytics queue (async, non-blocking)
    await _push_to_analytics(session_id, request.message, ai_response)

    return ChatResponse(
        response=ai_response,
        session_id=session_id,
        cached=False,
        sources=sources,
    )


@router.websocket("/ws/chat/{session_id}")
async def chat_websocket(websocket: WebSocket, session_id: str):
    """WebSocket endpoint for real-time chat."""
    await websocket.accept()
    logger.info(f"WebSocket connected: session={session_id}")

    try:
        while True:
            data = await websocket.receive_text()
            message = json.loads(data).get("message", "")

            if not message:
                await websocket.send_json({"error": "Empty message"})
                continue

            # Check cache
            cache_key = _generate_cache_key(message)
            cached = await cache.get(cache_key)
            if cached:
                await websocket.send_json({
                    "type": "response",
                    "content": cached,
                    "cached": True,
                })
                continue

            # RAG + LLM
            context_docs = await rag.retrieve(message)
            history = await sessions.get_history(session_id)

            # Stream response
            await websocket.send_json({"type": "stream_start"})
            full_response = ""

            async for chunk in bedrock.generate_response_stream(
                message=message,
                context=context_docs,
                history=history,
            ):
                full_response += chunk
                await websocket.send_json({
                    "type": "stream_chunk",
                    "content": chunk,
                })

            await websocket.send_json({"type": "stream_end"})

            # Cache + session update
            await cache.set(cache_key, full_response, ttl=settings.redis_cache_ttl)
            await sessions.add_message(session_id, "user", message)
            await sessions.add_message(session_id, "assistant", full_response)
            await _push_to_analytics(session_id, message, full_response)

    except WebSocketDisconnect:
        logger.info(f"WebSocket disconnected: session={session_id}")


@router.get("/sessions/{session_id}/history")
async def get_session_history(session_id: str):
    """Retrieve conversation history for a session."""
    history = await sessions.get_history(session_id)
    if not history:
        raise HTTPException(status_code=404, detail="Session not found")
    return {"session_id": session_id, "messages": history}


def _generate_cache_key(message: str) -> str:
    """SHA-256 hash of the message for cache key."""
    return f"llm_cache:{hashlib.sha256(message.strip().lower().encode()).hexdigest()}"


async def _push_to_analytics(session_id: str, user_msg: str, ai_response: str):
    """Push conversation turn to Redis queue for async analytics processing."""
    try:
        await cache.push_to_queue("analytics:sentiment_queue", json.dumps({
            "session_id": session_id,
            "user_message": user_msg,
            "ai_response": ai_response,
        }))
    except Exception as e:
        logger.warning(f"Failed to push to analytics queue: {e}")
