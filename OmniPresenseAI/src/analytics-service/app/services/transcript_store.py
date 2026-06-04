"""Transcript Store — S3 archival for chat transcripts."""
import json
import logging
from datetime import datetime
import boto3
from app.config import Settings

logger = logging.getLogger(__name__)

class TranscriptStore:
    """Archives and retrieves chat transcripts from S3."""

    def __init__(self, settings: Settings):
        self.settings = settings
        self.s3 = boto3.client("s3", region_name=settings.aws_region)
        self.bucket = settings.s3_transcripts_bucket

    async def store(self, session_id: str, transcript: dict) -> bool:
        """Store a transcript to S3."""
        try:
            date_prefix = datetime.utcnow().strftime("%Y/%m/%d")
            key = f"transcripts/{date_prefix}/{session_id}.json"
            self.s3.put_object(
                Bucket=self.bucket,
                Key=key,
                Body=json.dumps(transcript, indent=2, default=str),
                ContentType="application/json",
                ServerSideEncryption="aws:kms",
            )
            logger.info(f"Stored transcript: s3://{self.bucket}/{key}")
            return True
        except Exception as e:
            logger.error(f"Failed to store transcript: {e}")
            return False

    async def get(self, session_id: str) -> dict | None:
        """Retrieve a transcript from S3."""
        try:
            # Search recent dates for the session
            response = self.s3.list_objects_v2(
                Bucket=self.bucket,
                Prefix=f"transcripts/",
                MaxKeys=1000,
            )
            for obj in response.get("Contents", []):
                if session_id in obj["Key"]:
                    result = self.s3.get_object(Bucket=self.bucket, Key=obj["Key"])
                    return json.loads(result["Body"].read())
            return None
        except Exception as e:
            logger.error(f"Failed to retrieve transcript: {e}")
            return None
