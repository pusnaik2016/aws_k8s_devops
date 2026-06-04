"""RAG Engine — pgvector-based retrieval for knowledge base context."""

import logging
from typing import Optional

from app.config import Settings

logger = logging.getLogger(__name__)


class RAGEngine:
    """Retrieval-Augmented Generation using Aurora PostgreSQL + pgvector."""

    def __init__(self, settings: Settings):
        self.settings = settings
        self.top_k = settings.rag_top_k
        self.threshold = settings.rag_similarity_threshold
        self._pool = None

    async def _get_pool(self):
        """Lazy-initialize the database connection pool."""
        if self._pool is None:
            try:
                import asyncpg
                self._pool = await asyncpg.create_pool(
                    host=self.settings.database_host,
                    port=self.settings.database_port,
                    database=self.settings.database_name,
                    user=self.settings.database_user,
                    password=self.settings.database_password,
                    min_size=2,
                    max_size=10,
                )
                logger.info("Database connection pool initialized")
            except Exception as e:
                logger.error(f"Failed to initialize DB pool: {e}")
                return None
        return self._pool

    async def retrieve(self, query: str, top_k: Optional[int] = None) -> list[dict]:
        """Retrieve relevant documents using vector similarity search.

        1. Generate embedding for the query using Bedrock Titan
        2. Search pgvector for similar documents
        3. Return top-K results above similarity threshold
        """
        k = top_k or self.top_k

        try:
            # Import bedrock client for embedding
            from app.services.bedrock_client import BedrockClient
            bedrock = BedrockClient(self.settings)
            query_embedding = await bedrock.generate_embedding(query)

            pool = await self._get_pool()
            if not pool:
                logger.warning("No DB pool — returning empty context")
                return []

            # pgvector cosine similarity search
            async with pool.acquire() as conn:
                rows = await conn.fetch(
                    """
                    SELECT
                        content,
                        source,
                        category,
                        1 - (embedding <=> $1::vector) AS similarity
                    FROM knowledge_base
                    WHERE 1 - (embedding <=> $1::vector) > $2
                    ORDER BY embedding <=> $1::vector
                    LIMIT $3
                    """,
                    str(query_embedding),
                    self.threshold,
                    k,
                )

            return [
                {
                    "content": row["content"],
                    "source": row["source"],
                    "category": row.get("category", "general"),
                    "similarity": float(row["similarity"]),
                }
                for row in rows
            ]

        except Exception as e:
            logger.error(f"RAG retrieval failed: {e}")
            return []

    async def close(self):
        """Close the database connection pool."""
        if self._pool:
            await self._pool.close()
