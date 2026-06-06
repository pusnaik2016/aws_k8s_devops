"""Sentiment Analyzer — Bedrock-powered conversation analysis."""
import json
import logging
import boto3
from app.config import Settings

logger = logging.getLogger(__name__)

class SentimentAnalyzer:
    """Analyzes sentiment using Amazon Bedrock (Claude 3.5 Sonnet)."""

    PROMPT_TEMPLATE = """Analyze the sentiment of this customer support message.
Return ONLY valid JSON with no other text:
{{"sentiment": "positive|negative|neutral", "score": 0.0-1.0, "topics": ["topic1", "topic2"]}}

Score guide: 0.0 = very negative, 0.5 = neutral, 1.0 = very positive.

Message: "{message}"
"""

    def __init__(self, settings: Settings):
        self.settings = settings
        self.client = boto3.client("bedrock-runtime", region_name=settings.aws_region)

    async def analyze(self, message: str) -> dict:
        """Analyze sentiment of a message using Bedrock."""
        try:
            body = json.dumps({
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": 256,
                "temperature": 0.1,
                "messages": [
                    {"role": "user", "content": self.PROMPT_TEMPLATE.format(message=message)}
                ],
            })

            response = self.client.invoke_model(
                modelId=self.settings.bedrock_model_id,
                body=body,
                contentType="application/json",
                accept="application/json",
            )

            result = json.loads(response["body"].read())
            text = result["content"][0]["text"]
            return json.loads(text)

        except Exception as e:
            logger.error(f"Sentiment analysis failed: {e}")
            return {"sentiment": "neutral", "score": 0.5, "topics": []}
