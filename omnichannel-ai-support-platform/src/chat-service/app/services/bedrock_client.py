"""Amazon Bedrock Client — Claude 3.5 Sonnet + Titan Embeddings."""

import json
import logging
from typing import AsyncGenerator

import boto3

from app.config import Settings

logger = logging.getLogger(__name__)


class BedrockClient:
    """Wrapper for Amazon Bedrock API calls."""

    def __init__(self, settings: Settings):
        self.settings = settings
        self.client = boto3.client(
            "bedrock-runtime",
            region_name=settings.aws_region,
        )
        self.model_id = settings.bedrock_model_id
        self.embedding_model_id = settings.bedrock_embedding_model_id

    async def generate_response(
        self,
        message: str,
        context: list[dict] = None,
        history: list[dict] = None,
    ) -> str:
        """Generate a chat response using Claude 3.5 Sonnet."""
        messages = self._build_messages(message, context, history)

        body = json.dumps({
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": self.settings.llm_max_tokens,
            "temperature": self.settings.llm_temperature,
            "system": self.settings.llm_system_prompt,
            "messages": messages,
        })

        response = self.client.invoke_model(
            modelId=self.model_id,
            body=body,
            contentType="application/json",
            accept="application/json",
        )

        result = json.loads(response["body"].read())
        return result["content"][0]["text"]

    async def generate_response_stream(
        self,
        message: str,
        context: list[dict] = None,
        history: list[dict] = None,
    ) -> AsyncGenerator[str, None]:
        """Stream a chat response using Claude 3.5 Sonnet."""
        messages = self._build_messages(message, context, history)

        body = json.dumps({
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": self.settings.llm_max_tokens,
            "temperature": self.settings.llm_temperature,
            "system": self.settings.llm_system_prompt,
            "messages": messages,
        })

        response = self.client.invoke_model_with_response_stream(
            modelId=self.model_id,
            body=body,
            contentType="application/json",
            accept="application/json",
        )

        for event in response["body"]:
            chunk = json.loads(event["chunk"]["bytes"])
            if chunk.get("type") == "content_block_delta":
                yield chunk["delta"].get("text", "")

    async def generate_embedding(self, text: str) -> list[float]:
        """Generate text embedding using Titan Embeddings v2."""
        body = json.dumps({
            "inputText": text,
            "dimensions": 1024,
        })

        response = self.client.invoke_model(
            modelId=self.embedding_model_id,
            body=body,
            contentType="application/json",
            accept="application/json",
        )

        result = json.loads(response["body"].read())
        return result["embedding"]

    def _build_messages(
        self,
        message: str,
        context: list[dict] = None,
        history: list[dict] = None,
    ) -> list[dict]:
        """Build the messages array with RAG context."""
        messages = []

        # Add conversation history
        if history:
            for msg in history[-10:]:  # Last 10 messages for context window
                messages.append({
                    "role": msg["role"],
                    "content": msg["content"],
                })

        # Build user message with RAG context
        user_content = message
        if context:
            context_text = "\n\n".join([
                f"[Source: {doc.get('source', 'Knowledge Base')}]\n{doc.get('content', '')}"
                for doc in context
            ])
            user_content = (
                f"Context from knowledge base:\n{context_text}\n\n"
                f"Customer question: {message}"
            )

        messages.append({"role": "user", "content": user_content})
        return messages
