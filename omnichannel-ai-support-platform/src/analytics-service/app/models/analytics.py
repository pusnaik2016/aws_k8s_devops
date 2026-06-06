"""Analytics data models."""
from pydantic import BaseModel
from datetime import datetime

class ConversationMetrics(BaseModel):
    session_id: str
    sentiment_score: float
    topics: list[str] = []
    message_count: int = 0
    escalated: bool = False
    analyzed_at: datetime = None

class DashboardSummary(BaseModel):
    total_conversations: int
    avg_sentiment_score: float
    escalation_rate: float
    top_topics: list[str] = []
