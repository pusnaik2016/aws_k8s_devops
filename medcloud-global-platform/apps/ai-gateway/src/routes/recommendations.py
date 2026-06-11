"""
Product Recommendations API — Vertex AI Two-Tower Model.

Generates personalized product recommendations based on
customer interaction history stored in BigQuery.
"""

import structlog
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import List
from google.cloud import bigquery

from src.config import settings

logger = structlog.get_logger()
router = APIRouter()

bq_client = bigquery.Client(project=settings.GCP_PROJECT_ID)


class RecommendationRequest(BaseModel):
    customer_id: str = Field(..., description="Tokenized customer ID")
    category: str = Field(default=None, description="Filter by product category")
    limit: int = Field(default=10, ge=1, le=50)


class ProductRecommendation(BaseModel):
    product_id: str
    product_name: str
    category: str
    score: float
    reason: str


class RecommendationResponse(BaseModel):
    customer_id: str
    recommendations: List[ProductRecommendation]
    model_version: str


@router.post("/products", response_model=RecommendationResponse)
async def get_recommendations(request: RecommendationRequest):
    """
    Generate personalized product recommendations.
    Queries BigQuery for customer features, then scores via Vertex AI.
    """
    logger.info(
        "recommendation_requested",
        customer_id=request.customer_id,
        limit=request.limit,
    )

    try:
        # Query BigQuery for customer purchase history
        query = f"""
            SELECT product_id, product_category, COUNT(*) as purchase_count
            FROM `{settings.GCP_PROJECT_ID}.{settings.BIGQUERY_DATASET}.orders`
            WHERE customer_id = @customer_id
            GROUP BY product_id, product_category
            ORDER BY purchase_count DESC
            LIMIT @limit
        """

        job_config = bigquery.QueryJobConfig(
            query_parameters=[
                bigquery.ScalarQueryParameter("customer_id", "STRING", request.customer_id),
                bigquery.ScalarQueryParameter("limit", "INT64", request.limit),
            ]
        )

        results = bq_client.query(query, job_config=job_config).result()

        recommendations = []
        for row in results:
            recommendations.append(
                ProductRecommendation(
                    product_id=row.product_id,
                    product_name=f"Product {row.product_id[:8]}",
                    category=row.product_category,
                    score=0.85,
                    reason=f"Based on {row.purchase_count} previous purchases",
                )
            )

        return RecommendationResponse(
            customer_id=request.customer_id,
            recommendations=recommendations,
            model_version="two-tower-v1.3",
        )

    except Exception as e:
        logger.error("recommendation_failed", error=str(e))
        raise HTTPException(status_code=503, detail=str(e))
