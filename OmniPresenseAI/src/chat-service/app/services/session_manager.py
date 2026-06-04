"""Session Manager — WebSocket session state in Redis."""

import json
import uuid
import logging
from typing import Optional

import redis.asyncio as redis

from app.config import Settings

logger = logging.getLogger(__name__)


class SessionManager:
    """Manages chat session state using Redis."""

    SESSION_TTL = 86400  # 24 hours

    def __init__(self, settings: Settings):
        self.settings = settings
        self._redis: Optional[redis.Redis] = None

    async def _get_client(self) -> redis.Redis:
        if self._redis is None:
            self._redis = redis.Redis(
                host=self.settings.redis_host,
                port=self.settings.redis_port,
                password=self.settings.redis_password or None,
                ssl=self.settings.redis_ssl,
                decode_responses=True,
            )
        return self._redis

    def create_session(self, user_id: str = "anonymous") -> str:
        """Create a new session ID."""
        session_id = f"session:{uuid.uuid4().hex[:12]}"
        logger.info(f"Created session: {session_id} for user: {user_id}")
        return session_id

    async def add_message(self, session_id: str, role: str, content: str):
        """Add a message to the session history."""
        try:
            client = await self._get_client()
            key = f"history:{session_id}"
            message = json.dumps({"role": role, "content": content})
            await client.rpush(key, message)
            await client.expire(key, self.SESSION_TTL)
        except Exception as e:
            logger.warning(f"Failed to save message: {e}")

    async def get_history(self, session_id: str) -> list[dict]:
        """Get the full conversation history for a session."""
        try:
            client = await self._get_client()
            key = f"history:{session_id}"
            messages = await client.lrange(key, 0, -1)
            return [json.loads(m) for m in messages]
        except Exception as e:
            logger.warning(f"Failed to retrieve history: {e}")
            return []

    async def close(self):
        if self._redis:
            await self._redis.close()
