#!/usr/bin/env python3
"""
Seed Knowledge Base — OmniPresenseAI
─────────────────────────────────────
Seeds Aurora PostgreSQL (pgvector) with sample knowledge base documents.
Uses Amazon Bedrock Titan Embeddings v2 to generate vector embeddings.

Usage:
    pip install -r ../src/chat-service/requirements.txt
    python seed-knowledge-base.py

Environment Variables:
    DATABASE_URL    - Aurora PostgreSQL connection string
    AWS_REGION      - AWS region (default: us-east-1)

Prerequisites:
    - Aurora PostgreSQL cluster running with pgvector extension
    - AWS credentials configured (IRSA or local profile)
    - Python packages: asyncpg, boto3
"""

import asyncio
import json
import logging
import os
import sys
from datetime import datetime, timezone
from uuid import uuid4

try:
    import asyncpg
    import boto3
except ImportError:
    print("Missing dependencies. Install with:")
    print("  pip install asyncpg boto3")
    sys.exit(1)


# ─── Configuration ───────────────────────────────────────────

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://postgres:changeme@localhost:5432/omnipresense_ai"
)
AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
EMBEDDING_MODEL_ID = "amazon.titan-embed-text-v2:0"
EMBEDDING_DIMENSION = 1536

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)


# ─── Sample Knowledge Base Documents ────────────────────────

KNOWLEDGE_DOCUMENTS = [
    {
        "title": "Account Password Reset",
        "category": "account",
        "content": (
            "To reset your password, follow these steps: "
            "1. Go to the login page and click 'Forgot Password'. "
            "2. Enter the email address associated with your account. "
            "3. Check your email for a password reset link (check spam folder). "
            "4. Click the link and enter your new password (minimum 8 characters, "
            "one uppercase, one number, one special character). "
            "5. Log in with your new password. "
            "If you don't receive the email within 5 minutes, contact support."
        ),
    },
    {
        "title": "Billing and Payment Methods",
        "category": "billing",
        "content": (
            "We accept the following payment methods: Visa, Mastercard, "
            "American Express, PayPal, and bank transfers (ACH). "
            "To update your payment method: Go to Settings > Billing > "
            "Payment Methods. You can add, remove, or set a default payment method. "
            "Invoices are generated on the 1st of each month and are available "
            "in the Billing section. For enterprise customers, we offer NET-30 "
            "payment terms. Contact your account manager for details."
        ),
    },
    {
        "title": "Subscription Plans and Pricing",
        "category": "billing",
        "content": (
            "We offer three subscription tiers: "
            "1. Starter ($29/mo): Up to 5 users, 10GB storage, email support. "
            "2. Professional ($99/mo): Up to 25 users, 100GB storage, "
            "priority support, API access, advanced analytics. "
            "3. Enterprise (custom pricing): Unlimited users, unlimited storage, "
            "24/7 phone support, dedicated account manager, SLA, SSO/SAML. "
            "All plans include a 14-day free trial. No credit card required "
            "to start. Annual billing saves 20%."
        ),
    },
    {
        "title": "API Rate Limits and Quotas",
        "category": "technical",
        "content": (
            "API rate limits depend on your subscription plan: "
            "Starter: 100 requests/minute, 10,000 requests/day. "
            "Professional: 500 requests/minute, 100,000 requests/day. "
            "Enterprise: 2,000 requests/minute, unlimited daily. "
            "Rate limit headers are included in every response: "
            "X-RateLimit-Limit, X-RateLimit-Remaining, X-RateLimit-Reset. "
            "If you exceed the limit, you'll receive a 429 Too Many Requests "
            "response. Implement exponential backoff for retries. "
            "Contact support to request a rate limit increase."
        ),
    },
    {
        "title": "Data Export and GDPR Compliance",
        "category": "compliance",
        "content": (
            "You can export your data at any time from Settings > Data > Export. "
            "Supported formats: CSV, JSON, and PDF. Large exports are processed "
            "asynchronously — you'll receive an email when ready. "
            "Under GDPR, you have the right to: access your data, rectify "
            "inaccurate data, erase your data (right to be forgotten), "
            "restrict processing, data portability, and object to processing. "
            "To submit a GDPR request, email privacy@example.com or use the "
            "in-app privacy center. We respond within 30 days."
        ),
    },
    {
        "title": "Two-Factor Authentication (2FA) Setup",
        "category": "security",
        "content": (
            "We strongly recommend enabling two-factor authentication (2FA) "
            "for your account. Supported methods: "
            "1. Authenticator app (Google Authenticator, Authy, 1Password) — Recommended. "
            "2. SMS verification (less secure, not recommended for admin accounts). "
            "To enable: Settings > Security > Two-Factor Authentication > Enable. "
            "Scan the QR code with your authenticator app, then enter the 6-digit code. "
            "Save your backup codes in a secure location — you'll need them if you "
            "lose access to your authenticator. Enterprise plans can enforce 2FA "
            "for all organization members."
        ),
    },
    {
        "title": "Integration with Slack and Microsoft Teams",
        "category": "integrations",
        "content": (
            "Connect your account to Slack or Microsoft Teams for real-time "
            "notifications and quick actions. "
            "Slack: Go to Settings > Integrations > Slack > Connect. "
            "Authorize the app in your Slack workspace. Choose channels for "
            "notifications. Available commands: /status, /create-ticket, /search. "
            "Microsoft Teams: Go to Settings > Integrations > Teams > Connect. "
            "Install the app from the Teams App Store. Configure notification "
            "preferences in the app settings. Supports adaptive cards for "
            "interactive notifications."
        ),
    },
    {
        "title": "Troubleshooting Login Issues",
        "category": "account",
        "content": (
            "Common login issues and solutions: "
            "1. 'Invalid credentials': Double-check email and password. Passwords "
            "are case-sensitive. Try resetting your password. "
            "2. 'Account locked': After 5 failed attempts, accounts are locked "
            "for 30 minutes. Wait or contact support for immediate unlock. "
            "3. 'SSO not working': Verify your organization's SSO configuration. "
            "Check that your email domain matches the SSO domain. "
            "4. '2FA code invalid': Ensure your device clock is synchronized. "
            "Try a backup code if available. "
            "5. 'Browser issues': Clear cookies and cache. Try incognito mode. "
            "Supported browsers: Chrome 90+, Firefox 88+, Safari 14+, Edge 90+."
        ),
    },
    {
        "title": "Service Level Agreement (SLA)",
        "category": "compliance",
        "content": (
            "Our SLA guarantees for Enterprise customers: "
            "99.9% uptime for the core platform (measured monthly). "
            "Response times: SEV-1 (critical) — 15 minutes, "
            "SEV-2 (major) — 1 hour, SEV-3 (minor) — 4 hours, "
            "SEV-4 (low) — next business day. "
            "Planned maintenance windows: Sundays 2:00-6:00 AM UTC. "
            "Credit policy: Below 99.9% — 10% credit, below 99.5% — 25% credit, "
            "below 99.0% — 50% credit. "
            "Exclusions: Force majeure, customer-caused issues, beta features. "
            "SLA reports are available in the admin dashboard."
        ),
    },
    {
        "title": "Webhook Configuration",
        "category": "technical",
        "content": (
            "Webhooks allow you to receive real-time notifications when events "
            "occur in your account. "
            "Setup: Settings > Integrations > Webhooks > Add Endpoint. "
            "Provide an HTTPS URL. Select events to subscribe to: "
            "ticket.created, ticket.updated, ticket.resolved, user.created, "
            "payment.succeeded, payment.failed. "
            "Security: All webhook payloads include an HMAC-SHA256 signature "
            "in the X-Signature-256 header. Verify this signature to ensure "
            "the payload is authentic. "
            "Retry policy: Failed deliveries are retried 3 times with "
            "exponential backoff (1 min, 5 min, 30 min). "
            "After 3 failures, the webhook is disabled and you're notified."
        ),
    },
]


# ─── Embedding Generation ───────────────────────────────────

def get_bedrock_client():
    """Create Bedrock Runtime client."""
    return boto3.client(
        "bedrock-runtime",
        region_name=AWS_REGION,
    )


def generate_embedding(client, text: str) -> list[float]:
    """Generate embedding vector using Titan Embeddings v2."""
    response = client.invoke_model(
        modelId=EMBEDDING_MODEL_ID,
        contentType="application/json",
        accept="application/json",
        body=json.dumps({
            "inputText": text,
            "dimensions": EMBEDDING_DIMENSION,
        }),
    )
    result = json.loads(response["body"].read())
    return result["embedding"]


# ─── Database Operations ────────────────────────────────────

INIT_SQL = """
-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Knowledge documents table
CREATE TABLE IF NOT EXISTS knowledge_documents (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title       VARCHAR(500) NOT NULL,
    content     TEXT NOT NULL,
    category    VARCHAR(100),
    embedding   vector(1536),
    metadata    JSONB DEFAULT '{}',
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- HNSW index for fast cosine similarity search
CREATE INDEX IF NOT EXISTS idx_knowledge_embedding
    ON knowledge_documents
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

-- Category index for filtered queries
CREATE INDEX IF NOT EXISTS idx_knowledge_category
    ON knowledge_documents(category);

-- Chat sessions table
CREATE TABLE IF NOT EXISTS chat_sessions (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     VARCHAR(255),
    started_at  TIMESTAMPTZ DEFAULT NOW(),
    ended_at    TIMESTAMPTZ,
    metadata    JSONB DEFAULT '{}'
);

-- Chat messages table
CREATE TABLE IF NOT EXISTS chat_messages (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id  UUID REFERENCES chat_sessions(id),
    role        VARCHAR(20) NOT NULL,
    content     TEXT NOT NULL,
    tokens_used INTEGER,
    latency_ms  INTEGER,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Sentiment results table
CREATE TABLE IF NOT EXISTS sentiment_results (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id  UUID REFERENCES chat_sessions(id),
    score       FLOAT NOT NULL,
    label       VARCHAR(20) NOT NULL,
    analyzed_at TIMESTAMPTZ DEFAULT NOW()
);
"""

INSERT_SQL = """
INSERT INTO knowledge_documents (id, title, content, category, embedding, metadata, created_at)
VALUES ($1, $2, $3, $4, $5, $6, $7)
ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    content = EXCLUDED.content,
    category = EXCLUDED.category,
    embedding = EXCLUDED.embedding,
    metadata = EXCLUDED.metadata,
    updated_at = NOW();
"""


async def seed_database():
    """Main seeding function."""
    logger.info("Connecting to database...")
    conn = await asyncpg.connect(DATABASE_URL)

    try:
        # Initialize schema
        logger.info("Initializing database schema...")
        await conn.execute(INIT_SQL)
        logger.info("Schema initialized successfully")

        # Create Bedrock client
        logger.info("Connecting to Amazon Bedrock...")
        bedrock = get_bedrock_client()

        # Seed documents
        total = len(KNOWLEDGE_DOCUMENTS)
        logger.info(f"Seeding {total} knowledge base documents...")

        for i, doc in enumerate(KNOWLEDGE_DOCUMENTS, 1):
            doc_id = uuid4()
            logger.info(f"  [{i}/{total}] Generating embedding for: {doc['title']}")

            # Generate embedding
            embedding = generate_embedding(bedrock, doc["content"])

            # Format embedding for pgvector
            embedding_str = f"[{','.join(str(x) for x in embedding)}]"

            # Insert document
            await conn.execute(
                INSERT_SQL,
                doc_id,
                doc["title"],
                doc["content"],
                doc["category"],
                embedding_str,
                json.dumps({"source": "seed-script", "version": "1.0"}),
                datetime.now(timezone.utc),
            )

            logger.info(f"  [{i}/{total}] ✓ Inserted: {doc['title']}")

        # Verify
        count = await conn.fetchval("SELECT COUNT(*) FROM knowledge_documents")
        logger.info(f"\nSeeding complete! Total documents in knowledge base: {count}")

        # Test similarity search
        logger.info("\nTesting similarity search...")
        test_query = "How do I reset my password?"
        test_embedding = generate_embedding(bedrock, test_query)
        test_embedding_str = f"[{','.join(str(x) for x in test_embedding)}]"

        results = await conn.fetch(
            """
            SELECT title, 1 - (embedding <=> $1::vector) AS similarity
            FROM knowledge_documents
            ORDER BY embedding <=> $1::vector
            LIMIT 3
            """,
            test_embedding_str,
        )

        logger.info(f"Query: '{test_query}'")
        logger.info("Top-3 results:")
        for row in results:
            logger.info(f"  {row['similarity']:.4f} — {row['title']}")

    finally:
        await conn.close()
        logger.info("\nDatabase connection closed.")


# ─── Main ────────────────────────────────────────────────────

if __name__ == "__main__":
    print()
    print("═" * 55)
    print("  OmniPresenseAI — Knowledge Base Seeder")
    print("═" * 55)
    print()
    print(f"  Database: {DATABASE_URL.split('@')[-1] if '@' in DATABASE_URL else DATABASE_URL}")
    print(f"  Region:   {AWS_REGION}")
    print(f"  Model:    {EMBEDDING_MODEL_ID}")
    print(f"  Documents: {len(KNOWLEDGE_DOCUMENTS)}")
    print()

    try:
        asyncio.run(seed_database())
    except KeyboardInterrupt:
        print("\nAborted by user.")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Seeding failed: {e}")
        sys.exit(1)
