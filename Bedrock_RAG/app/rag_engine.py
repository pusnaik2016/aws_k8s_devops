"""
RAG Engine — Retrieval-Augmented Generation pipeline.

Flow: Query → Embed → OpenSearch kNN search → Retrieve top-K chunks
     → Build prompt with context → Invoke Bedrock Claude → Return answer
"""
import json
import logging
import os

import boto3
from opensearchpy import OpenSearch, RequestsHttpConnection
from requests_aws4auth import AWS4Auth

from embeddings import generate_embedding

logger = logging.getLogger(__name__)


class RAGEngine:
    """
    Production RAG pipeline using OpenSearch Serverless as the vector store
    and Amazon Bedrock Claude as the LLM.
    """

    def __init__(
        self,
        opensearch_endpoint: str,
        index_name: str,
        model_id: str,
        embedding_model_id: str,
    ):
        self.index_name = index_name
        self.model_id = model_id
        self.embedding_model_id = embedding_model_id
        self.bedrock = boto3.client("bedrock-runtime")

        # OpenSearch Serverless client with IAM auth
        region = os.environ.get("AWS_REGION", "us-east-1")
        credentials = boto3.Session().get_credentials()
        awsauth = AWS4Auth(
            credentials.access_key,
            credentials.secret_key,
            region,
            "aoss",
            session_token=credentials.token,
        )

        # Remove https:// prefix if present for host
        host = opensearch_endpoint.replace("https://", "")

        self.opensearch = OpenSearch(
            hosts=[{"host": host, "port": 443}],
            http_auth=awsauth,
            use_ssl=True,
            verify_certs=True,
            connection_class=RequestsHttpConnection,
            timeout=30,
        )

        logger.info(f"RAG Engine initialized — index: {index_name}, model: {model_id}")

    def _search_similar(self, query_embedding: list[float], top_k: int = 5) -> list[dict]:
        """
        Perform kNN vector search on OpenSearch Serverless.
        Returns the top-K most relevant document chunks.
        """
        search_body = {
            "size": top_k,
            "query": {
                "knn": {
                    "embedding": {
                        "vector": query_embedding,
                        "k": top_k,
                    }
                }
            },
            "_source": ["text", "metadata", "source_file", "chunk_id"],
        }

        try:
            response = self.opensearch.search(
                index=self.index_name,
                body=search_body,
            )

            hits = response["hits"]["hits"]
            results = []
            for hit in hits:
                results.append({
                    "text": hit["_source"]["text"],
                    "score": hit["_score"],
                    "source": hit["_source"].get("source_file", "unknown"),
                    "chunk_id": hit["_source"].get("chunk_id", ""),
                    "metadata": hit["_source"].get("metadata", {}),
                })

            logger.info(f"Found {len(results)} similar chunks (best score: {results[0]['score']:.4f})" if results else "No results found")
            return results

        except Exception as e:
            logger.error(f"OpenSearch search failed: {e}")
            return []

    def _build_prompt(self, query: str, context_chunks: list[dict]) -> str:
        """
        Build a grounded prompt with retrieved context.
        Includes instructions to cite sources and avoid hallucination.
        """
        context_text = "\n\n---\n\n".join(
            f"[Source: {chunk['source']}]\n{chunk['text']}"
            for chunk in context_chunks
        )

        return f"""You are an enterprise knowledge assistant. Answer questions accurately
based ONLY on the provided context. If the context doesn't contain enough
information to answer, say "I don't have enough information to answer that."

IMPORTANT RULES:
1. Only use information from the provided context
2. Cite the source document when referencing specific information
3. If you're not confident, say so
4. Be concise but thorough
5. Use bullet points for lists

CONTEXT:
{context_text}

USER QUESTION: {query}

ANSWER:"""

    def _invoke_bedrock(self, prompt: str) -> dict:
        """
        Invoke Amazon Bedrock Claude with the constructed prompt.
        Returns the generated answer and token usage.
        """
        messages = [{"role": "user", "content": prompt}]

        payload = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 2048,
            "temperature": 0.1,  # Low temperature for factual answers
            "top_p": 0.9,
            "messages": messages,
            "system": "You are a helpful enterprise knowledge assistant. Always ground your answers in the provided context.",
        }

        response = self.bedrock.invoke_model(
            modelId=self.model_id,
            contentType="application/json",
            accept="application/json",
            body=json.dumps(payload),
        )

        result = json.loads(response["body"].read())

        return {
            "text": result["content"][0]["text"],
            "input_tokens": result["usage"]["input_tokens"],
            "output_tokens": result["usage"]["output_tokens"],
        }

    def generate(self, query: str, top_k: int = 5) -> dict:
        """
        Full RAG pipeline: embed → search → prompt → generate.

        Args:
            query: User's question.
            top_k: Number of context chunks to retrieve.

        Returns:
            Dict with answer, sources, and token usage.
        """
        # Step 1: Embed the query
        logger.info(f"Step 1: Embedding query — '{query[:50]}...'")
        query_embedding = generate_embedding(query, self.embedding_model_id)

        # Step 2: Search for relevant chunks
        logger.info(f"Step 2: Searching OpenSearch — top_k={top_k}")
        context_chunks = self._search_similar(query_embedding, top_k)

        if not context_chunks:
            return {
                "answer": "I couldn't find any relevant information in the knowledge base. Please try rephrasing your question.",
                "sources": [],
                "token_usage": {},
            }

        # Step 3: Build prompt with context
        logger.info(f"Step 3: Building prompt with {len(context_chunks)} chunks")
        prompt = self._build_prompt(query, context_chunks)

        # Step 4: Invoke Bedrock
        logger.info("Step 4: Invoking Bedrock Claude")
        llm_result = self._invoke_bedrock(prompt)

        # Step 5: Format response
        sources = list({chunk["source"] for chunk in context_chunks})

        return {
            "answer": llm_result["text"],
            "sources": sources,
            "context_chunks": len(context_chunks),
            "token_usage": {
                "input_tokens": llm_result["input_tokens"],
                "output_tokens": llm_result["output_tokens"],
                "estimated_cost_usd": round(
                    (llm_result["input_tokens"] * 0.003 + llm_result["output_tokens"] * 0.015) / 1000,
                    6,
                ),
            },
        }
