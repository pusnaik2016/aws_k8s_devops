"""
CAG Engine — Cache-Augmented Generation pipeline.

Instead of vector search, CAG loads the ENTIRE knowledge base into the
prompt and uses Claude's prompt caching feature. This is optimal for
small-to-medium knowledge bases (< 100 pages) where:
  - The full context fits within the model's context window
  - The same knowledge base is queried frequently
  - Cost reduction via cache hits is a priority (up to 90% savings)

Flow: Load KB from S3 (cached in memory) → Build cached prompt → Invoke Bedrock
"""
import json
import logging
import os

import boto3

logger = logging.getLogger(__name__)


class CAGEngine:
    """
    Cache-Augmented Generation engine.
    Loads the full knowledge base into memory and uses Bedrock prompt caching.
    """

    def __init__(self, model_id: str, s3_bucket: str):
        self.model_id = model_id
        self.s3_bucket = s3_bucket
        self.bedrock = boto3.client("bedrock-runtime")
        self.s3 = boto3.client("s3")

        # In-memory cache of the knowledge base (persists across warm Lambda invocations)
        self._knowledge_base: str | None = None

        logger.info(f"CAG Engine initialized — model: {model_id}, bucket: {s3_bucket}")

    def _load_knowledge_base(self) -> str:
        """
        Load the entire processed knowledge base from S3.
        Caches in Lambda memory for subsequent invocations.
        """
        if self._knowledge_base is not None:
            logger.info("Using cached knowledge base from memory")
            return self._knowledge_base

        logger.info("Loading knowledge base from S3...")

        # List all processed text files
        paginator = self.s3.get_paginator("list_objects_v2")
        pages = paginator.paginate(Bucket=self.s3_bucket, Prefix="processed/")

        documents = []
        for page in pages:
            for obj in page.get("Contents", []):
                if obj["Key"].endswith(".txt"):
                    response = self.s3.get_object(Bucket=self.s3_bucket, Key=obj["Key"])
                    content = response["Body"].read().decode("utf-8")
                    doc_name = obj["Key"].split("/")[-1]
                    documents.append(f"[Document: {doc_name}]\n{content}")

        self._knowledge_base = "\n\n---\n\n".join(documents)
        logger.info(f"Loaded {len(documents)} documents, {len(self._knowledge_base)} characters")

        return self._knowledge_base

    def generate(self, query: str) -> dict:
        """
        Generate an answer using the full knowledge base with prompt caching.

        The system prompt containing the knowledge base is marked with
        cache_control to enable Bedrock prompt caching. Subsequent queries
        reuse the cached prefix, reducing input token costs by ~90%.

        Args:
            query: User's question.

        Returns:
            Dict with answer, sources, and token usage.
        """
        knowledge_base = self._load_knowledge_base()

        if not knowledge_base:
            return {
                "answer": "No documents found in the knowledge base. Please upload documents first.",
                "sources": [],
                "token_usage": {},
            }

        # Build the request with prompt caching enabled
        # The system message (containing the KB) is cached; only the user query
        # consumes fresh input tokens on subsequent calls.
        system_prompt = f"""You are an enterprise knowledge assistant with access to the
complete knowledge base below. Answer questions accurately based ONLY on this content.

RULES:
1. Only use information from the knowledge base below
2. Cite the document name when referencing information
3. If the answer is not in the knowledge base, say so clearly
4. Be concise but thorough

KNOWLEDGE BASE:
{knowledge_base}"""

        payload = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 2048,
            "temperature": 0.1,
            "messages": [
                {"role": "user", "content": query}
            ],
            "system": [
                {
                    "type": "text",
                    "text": system_prompt,
                    "cache_control": {"type": "ephemeral"},  # Enable prompt caching
                }
            ],
        }

        logger.info(f"Invoking Bedrock with CAG — KB size: {len(knowledge_base)} chars")

        response = self.bedrock.invoke_model(
            modelId=self.model_id,
            contentType="application/json",
            accept="application/json",
            body=json.dumps(payload),
        )

        result = json.loads(response["body"].read())

        usage = result.get("usage", {})
        cache_read = usage.get("cache_read_input_tokens", 0)
        cache_creation = usage.get("cache_creation_input_tokens", 0)

        logger.info(
            f"CAG response — input: {usage.get('input_tokens', 0)}, "
            f"output: {usage.get('output_tokens', 0)}, "
            f"cache_read: {cache_read}, cache_creation: {cache_creation}"
        )

        return {
            "answer": result["content"][0]["text"],
            "sources": ["Full knowledge base (CAG mode)"],
            "token_usage": {
                "input_tokens": usage.get("input_tokens", 0),
                "output_tokens": usage.get("output_tokens", 0),
                "cache_read_tokens": cache_read,
                "cache_creation_tokens": cache_creation,
                "cache_hit": cache_read > 0,
                "estimated_cost_usd": round(
                    (
                        usage.get("input_tokens", 0) * 0.003
                        + usage.get("output_tokens", 0) * 0.015
                        + cache_read * 0.0003          # 90% cheaper for cached tokens
                        + cache_creation * 0.00375     # 25% premium for cache creation
                    ) / 1000,
                    6,
                ),
            },
        }
