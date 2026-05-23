"""
Document Ingestion Pipeline — S3 trigger handler.

Triggered when a document is uploaded to s3://bucket/documents/.
Parses the document, chunks it semantically, generates embeddings,
and indexes into OpenSearch Serverless for RAG retrieval.

Supported formats: .txt, .md, .pdf (basic)
"""
import json
import logging
import os
import re
import urllib.parse

import boto3
from opensearchpy import OpenSearch, RequestsHttpConnection
from requests_aws4auth import AWS4Auth

from embeddings import generate_embedding

logger = logging.getLogger(__name__)
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

# Configuration
CHUNK_SIZE = int(os.environ.get("CHUNK_SIZE", "512"))
CHUNK_OVERLAP = int(os.environ.get("CHUNK_OVERLAP", "50"))
INDEX_NAME = os.environ.get("INDEX_NAME", "rag-knowledge-base")
EMBEDDING_MODEL_ID = os.environ.get("EMBEDDING_MODEL_ID", "amazon.titan-embed-text-v2:0")


def _get_opensearch_client():
    """Create OpenSearch Serverless client with IAM auth."""
    region = os.environ.get("AWS_REGION", "us-east-1")
    credentials = boto3.Session().get_credentials()
    awsauth = AWS4Auth(
        credentials.access_key,
        credentials.secret_key,
        region,
        "aoss",
        session_token=credentials.token,
    )

    endpoint = os.environ["OPENSEARCH_ENDPOINT"].replace("https://", "")

    return OpenSearch(
        hosts=[{"host": endpoint, "port": 443}],
        http_auth=awsauth,
        use_ssl=True,
        verify_certs=True,
        connection_class=RequestsHttpConnection,
        timeout=30,
    )


def _ensure_index(client: OpenSearch):
    """
    Create the vector index if it doesn't exist.
    Uses HNSW algorithm with cosine similarity for nearest-neighbor search.
    """
    if client.indices.exists(index=INDEX_NAME):
        logger.info(f"Index '{INDEX_NAME}' already exists")
        return

    index_body = {
        "settings": {
            "index": {
                "knn": True,
                "knn.algo_param.ef_search": 512,
            }
        },
        "mappings": {
            "properties": {
                "embedding": {
                    "type": "knn_vector",
                    "dimension": 1024,
                    "method": {
                        "name": "hnsw",
                        "engine": "nmslib",
                        "space_type": "cosinesimil",
                        "parameters": {
                            "ef_construction": 512,
                            "m": 16,
                        },
                    },
                },
                "text": {"type": "text"},
                "source_file": {"type": "keyword"},
                "chunk_id": {"type": "keyword"},
                "metadata": {
                    "type": "object",
                    "properties": {
                        "file_type": {"type": "keyword"},
                        "upload_date": {"type": "date"},
                        "chunk_index": {"type": "integer"},
                        "total_chunks": {"type": "integer"},
                    },
                },
            }
        },
    }

    client.indices.create(index=INDEX_NAME, body=index_body)
    logger.info(f"Created index '{INDEX_NAME}' with kNN vector mapping")


def _chunk_text(text: str, chunk_size: int = CHUNK_SIZE, overlap: int = CHUNK_OVERLAP) -> list[str]:
    """
    Split text into overlapping chunks using semantic boundaries.
    Prefers splitting at paragraph/sentence boundaries over hard cuts.
    """
    # Clean the text
    text = re.sub(r'\n{3,}', '\n\n', text).strip()

    if len(text) <= chunk_size:
        return [text]

    chunks = []

    # Split by paragraphs first
    paragraphs = text.split("\n\n")
    current_chunk = ""

    for para in paragraphs:
        if len(current_chunk) + len(para) + 2 <= chunk_size:
            current_chunk += ("\n\n" if current_chunk else "") + para
        else:
            if current_chunk:
                chunks.append(current_chunk.strip())
            # If a single paragraph exceeds chunk_size, split by sentences
            if len(para) > chunk_size:
                sentences = re.split(r'(?<=[.!?])\s+', para)
                current_chunk = ""
                for sentence in sentences:
                    if len(current_chunk) + len(sentence) + 1 <= chunk_size:
                        current_chunk += (" " if current_chunk else "") + sentence
                    else:
                        if current_chunk:
                            chunks.append(current_chunk.strip())
                        current_chunk = sentence
            else:
                current_chunk = para

    if current_chunk.strip():
        chunks.append(current_chunk.strip())

    # Add overlap between chunks
    if overlap > 0 and len(chunks) > 1:
        overlapped_chunks = [chunks[0]]
        for i in range(1, len(chunks)):
            prev_words = chunks[i - 1].split()
            overlap_text = " ".join(prev_words[-overlap:])
            overlapped_chunks.append(overlap_text + " " + chunks[i])
        chunks = overlapped_chunks

    logger.info(f"Text chunked into {len(chunks)} chunks (avg {sum(len(c) for c in chunks) // len(chunks)} chars)")
    return chunks


def _read_document(bucket: str, key: str) -> str:
    """Read document content from S3."""
    s3 = boto3.client("s3")
    response = s3.get_object(Bucket=bucket, Key=key)
    content = response["Body"].read().decode("utf-8", errors="replace")
    logger.info(f"Read document: s3://{bucket}/{key} ({len(content)} chars)")
    return content


def _save_processed(bucket: str, key: str, content: str):
    """Save processed text to s3://bucket/processed/ for CAG engine."""
    s3 = boto3.client("s3")
    filename = key.split("/")[-1].rsplit(".", 1)[0] + ".txt"
    processed_key = f"processed/{filename}"
    s3.put_object(Bucket=bucket, Key=processed_key, Body=content.encode("utf-8"))
    logger.info(f"Saved processed document: s3://{bucket}/{processed_key}")


def handler(event, context):
    """
    Lambda handler triggered by S3 document upload.
    Processes the document, chunks it, generates embeddings,
    and indexes into OpenSearch.
    """
    logger.info(f"Ingest event: {json.dumps(event, default=str)}")

    os_client = _get_opensearch_client()
    _ensure_index(os_client)

    for record in event.get("Records", []):
        bucket = record["s3"]["bucket"]["name"]
        key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])

        logger.info(f"Processing: s3://{bucket}/{key}")

        # Step 1: Read document
        content = _read_document(bucket, key)

        if not content.strip():
            logger.warning(f"Empty document: {key}")
            continue

        # Step 2: Save processed text for CAG engine
        _save_processed(bucket, key, content)

        # Step 3: Chunk the document
        chunks = _chunk_text(content)

        # Step 4: Embed and index each chunk
        filename = key.split("/")[-1]
        indexed_count = 0

        for i, chunk_text in enumerate(chunks):
            try:
                # Generate embedding
                embedding = generate_embedding(chunk_text, EMBEDDING_MODEL_ID)

                # Index in OpenSearch
                doc = {
                    "text": chunk_text,
                    "embedding": embedding,
                    "source_file": filename,
                    "chunk_id": f"{filename}-chunk-{i}",
                    "metadata": {
                        "file_type": filename.rsplit(".", 1)[-1] if "." in filename else "unknown",
                        "upload_date": record["eventTime"],
                        "chunk_index": i,
                        "total_chunks": len(chunks),
                    },
                }

                os_client.index(
                    index=INDEX_NAME,
                    body=doc,
                    id=f"{filename}-{i}",
                )
                indexed_count += 1

            except Exception as e:
                logger.error(f"Failed to index chunk {i} of {filename}: {e}")

        logger.info(f"Indexed {indexed_count}/{len(chunks)} chunks for {filename}")

    return {
        "statusCode": 200,
        "body": json.dumps({"message": "Ingestion complete"}),
    }
