"""Redis Cache Service — LLM response caching + analytics queue."""

import logging
from typing import Optional

import redis.asyncio as redis

from app.config import Settings

logger = logging.getLogger(__name__)


class CacheService:
    """ElastiCache Redis wrapper for LLM caching and message queuing."""

    def __init__(self, settings: Settings):
        self.settings = settings
        self._redis: Optional[redis.Redis] = None

    async def _get_client(self) -> redis.Redis:
        """Lazy-initialize Redis connection."""
        if self._redis is None:
            self._redis = redis.Redis(
                host=self.settings.redis_host,
                port=self.settings.redis_port,
                password=self.settings.redis_password or None,
                ssl=self.settings.redis_ssl,
                decode_responses=True,
            )
        return self._redis

    async def get(self, key: str) -> Optional[str]:
        """Get a cached value. Returns None on miss."""
        try:
            client = await self._get_client()
            value = await client.get(key)
            if value:
                logger.debug(f"Cache HIT: {key[:32]}...")
            return value
        except Exception as e:
            logger.warning(f"Redis GET failed: {e}")
            return None

    async def set(self, key: str, value: str, ttl: int = 3600) -> bool:
        """Set a cached value with TTL (default 1 hour)."""
        try:
            client = await self._get_client()
            await client.setex(key, ttl, value)
            logger.debug(f"Cache SET: {key[:32]}... TTL={ttl}s")
            return True
        except Exception as e:
            logger.warning(f"Redis SET failed: {e}")
            return False

    async def push_to_queue(self, queue_name: str, message: str) -> bool:
        """Push a message to a Redis list (queue for analytics)."""
        try:
            client = await self._get_client()
            await client.rpush(queue_name, message)
            return True
        except Exception as e:
            logger.warning(f"Redis RPUSH failed: {e}")
            return False

    async def close(self):
        """Close the Redis connection."""
        if self._redis:
            await self._redis.close()
