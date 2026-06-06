"""Metrics Aggregator — Conversation analytics dashboard data."""
import logging
from app.config import Settings

logger = logging.getLogger(__name__)

class MetricsAggregator:
    """Aggregates conversation metrics for the analytics dashboard."""

    def __init__(self, settings: Settings):
        self.settings = settings

    async def get_summary(self) -> dict:
        """Get aggregated metrics summary.
        In production, this queries Aurora for historical data."""
        return {
            "total_conversations": 0,
            "avg_sentiment_score": 0.0,
            "escalation_rate": 0.0,
            "avg_response_time_ms": 0,
            "cache_hit_rate": 0.0,
            "top_topics": [],
            "sentiment_distribution": {
                "positive": 0,
                "neutral": 0,
                "negative": 0,
            },
        }
