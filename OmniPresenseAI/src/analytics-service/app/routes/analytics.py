"""Analytics endpoints — sentiment analysis and metrics."""
import json
import logging
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from app.config import get_settings
from app.services.sentiment_analyzer import SentimentAnalyzer
from app.services.transcript_store import TranscriptStore
from app.services.metrics_aggregator import MetricsAggregator

logger = logging.getLogger(__name__)
router = APIRouter(tags=["Analytics"])
settings = get_settings()
sentiment = SentimentAnalyzer(settings)
transcripts = TranscriptStore(settings)
metrics = MetricsAggregator(settings)

class SentimentRequest(BaseModel):
    message: str
    session_id: str = ""

class SentimentResponse(BaseModel):
    sentiment: str  # positive, negative, neutral
    score: float
    topics: list[str] = []
    escalation_recommended: bool = False

@router.post("/analytics/sentiment", response_model=SentimentResponse)
async def analyze_sentiment(request: SentimentRequest):
    """Analyze the sentiment of a customer message."""
    result = await sentiment.analyze(request.message)
    return SentimentResponse(
        sentiment=result["sentiment"],
        score=result["score"],
        topics=result.get("topics", []),
        escalation_recommended=result["score"] < 0.3,
    )

@router.get("/analytics/metrics")
async def get_metrics():
    """Get aggregated analytics metrics."""
    return await metrics.get_summary()

@router.get("/analytics/transcripts/{session_id}")
async def get_transcript(session_id: str):
    """Retrieve an archived transcript from S3."""
    transcript = await transcripts.get(session_id)
    if not transcript:
        raise HTTPException(status_code=404, detail="Transcript not found")
    return transcript
