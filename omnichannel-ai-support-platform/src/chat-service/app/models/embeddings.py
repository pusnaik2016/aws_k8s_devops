"""Vector embedding models."""
from pydantic import BaseModel
from typing import Optional

class KnowledgeDocument(BaseModel):
    content: str
    source: str
    category: str = "general"
    embedding: Optional[list[float]] = None

class SimilarityResult(BaseModel):
    content: str
    source: str
    similarity: float
    category: str = "general"
