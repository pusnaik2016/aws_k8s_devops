"""
Embeddings Module — Amazon Titan Embed Text v2 wrapper.

Generates vector embeddings for both document chunks (indexing)
and user queries (search).
"""
import json
import logging

import boto3

logger = logging.getLogger(__name__)

# Reuse client across invocations (Lambda warm start)
_bedrock_client = None


def _get_client():
    global _bedrock_client
    if _bedrock_client is None:
        _bedrock_client = boto3.client("bedrock-runtime")
    return _bedrock_client


def generate_embedding(text: str, model_id: str = "amazon.titan-embed-text-v2:0") -> list[float]:
    """
    Generate a vector embedding for the given text using Amazon Titan Embed v2.

    Args:
        text: Input text to embed (max 8192 tokens).
        model_id: Bedrock embedding model ID.

    Returns:
        List of floats representing the embedding vector (1024 dimensions).
    """
    client = _get_client()

    # Titan Embed v2 supports 256, 512, or 1024 dimensions
    payload = {
        "inputText": text,
        "dimensions": 1024,
        "normalize": True,
    }

    response = client.invoke_model(
        modelId=model_id,
        contentType="application/json",
        accept="application/json",
        body=json.dumps(payload),
    )

    result = json.loads(response["body"].read())
    embedding = result["embedding"]

    logger.debug(f"Generated embedding: {len(embedding)} dimensions for {len(text)} chars")
    return embedding


def generate_embeddings_batch(texts: list[str], model_id: str = "amazon.titan-embed-text-v2:0") -> list[list[float]]:
    """
    Generate embeddings for multiple texts.
    Titan Embed v2 doesn't support native batching, so we iterate.

    Args:
        texts: List of text strings to embed.
        model_id: Bedrock embedding model ID.

    Returns:
        List of embedding vectors.
    """
    embeddings = []
    for i, text in enumerate(texts):
        try:
            emb = generate_embedding(text, model_id)
            embeddings.append(emb)
        except Exception as e:
            logger.error(f"Failed to embed text {i}: {e}")
            embeddings.append([0.0] * 1024)  # Zero vector as fallback

    logger.info(f"Generated {len(embeddings)} embeddings")
    return embeddings
