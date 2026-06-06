"""Chat data models."""
from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class Message(BaseModel):
    role: str  # "user" or "assistant"
    content: str
    timestamp: datetime = None

class ChatSession(BaseModel):
    session_id: str
    user_id: str = "anonymous"
    messages: list[Message] = []
    created_at: datetime = None
    metadata: dict = {}
