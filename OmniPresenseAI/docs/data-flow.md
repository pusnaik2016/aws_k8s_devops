# Data Flow — OmniPresenseAI

> Request lifecycle documentation for the Omnichannel AI-Powered Customer Support & Analytics Platform.

---

## Table of Contents

1. [Chat Request Lifecycle](#chat-request-lifecycle)
2. [RAG Pipeline](#rag-pipeline)
3. [Analytics Pipeline](#analytics-pipeline)
4. [Session Management](#session-management)
5. [Data Retention & Lifecycle](#data-retention--lifecycle)

---

## Chat Request Lifecycle

### WebSocket Connection Flow

```mermaid
sequenceDiagram
    participant U as User Browser
    participant CF as CloudFront
    participant APIGW as API Gateway (WebSocket)
    participant ALB as Application Load Balancer
    participant CS as Chat Service (FastAPI)
    participant R as Redis Cache
    participant T as Titan Embeddings
    participant PG as Aurora pgvector
    participant LLM as Claude 3.5 Sonnet

    U->>CF: wss://domain/ws/chat/{session_id}
    CF->>APIGW: Forward WebSocket
    APIGW->>ALB: Route to EKS
    ALB->>CS: Establish WS connection

    Note over CS,R: Session Initialization
    CS->>R: Load/Create session state
    R-->>CS: Session context (history, metadata)

    U->>CS: Send message (JSON)
    
    Note over CS,R: Cache Check
    CS->>R: Check response cache (hash of query + context)
    
    alt Cache Hit
        R-->>CS: Cached response
        CS-->>U: Stream cached response
    else Cache Miss
        Note over CS,PG: RAG Retrieval
        CS->>T: Generate embedding (1536-dim)
        T-->>CS: Query vector
        CS->>PG: pgvector similarity search (top-5)
        PG-->>CS: Relevant knowledge chunks
        
        Note over CS,LLM: LLM Generation
        CS->>LLM: Prompt (system + context + history + query)
        LLM-->>CS: Stream response tokens
        CS-->>U: Stream to user (real-time)
        
        Note over CS,R: Post-Response
        CS->>R: Cache response (TTL: 1 hour)
        CS->>R: Update session history
        CS->>R: Push to analytics queue
    end
```

### REST Fallback Flow

```mermaid
graph LR
    A["POST /api/v1/chat"] --> B["API Gateway<br>REST API"]
    B --> C["ALB"]
    C --> D["Chat Service"]
    D --> E{"Cache?"}
    E -->|Hit| F["Return 200 OK"]
    E -->|Miss| G["RAG + LLM Pipeline"]
    G --> H["Return 200 OK<br>(Full response)"]

    style F fill:#2ecc71,color:#fff
    style G fill:#ff9900,color:#fff
```

---

## RAG Pipeline

### Embedding Generation & Vector Search

```mermaid
graph TB
    subgraph "Query Processing"
        Q["User Query"] --> PREP["Preprocessing<br>Normalize, truncate"]
        PREP --> EMBED["Titan Embeddings v2<br>Generate 1536-dim vector"]
    end

    subgraph "Knowledge Retrieval"
        EMBED --> SEARCH["pgvector<br>cosine_similarity search"]
        SEARCH --> FILTER["Score Threshold<br>≥ 0.7 similarity"]
        FILTER --> TOP5["Top-5 Chunks<br>Ranked by relevance"]
    end

    subgraph "Context Assembly"
        TOP5 --> CTX["Context Window<br>System prompt + chunks"]
        HIST["Session History<br>Last 10 messages"] --> CTX
        Q --> CTX
    end

    subgraph "LLM Inference"
        CTX --> CLAUDE["Claude 3.5 Sonnet<br>Max 2048 tokens"]
        CLAUDE --> STREAM["Stream Response<br>Token by token"]
    end

    style EMBED fill:#ff9900,color:#fff
    style SEARCH fill:#3b48cc,color:#fff
    style CLAUDE fill:#ff9900,color:#fff
```

### Knowledge Base Schema (Aurora pgvector)

```sql
-- Knowledge documents table
CREATE TABLE knowledge_documents (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title       VARCHAR(500) NOT NULL,
    content     TEXT NOT NULL,
    category    VARCHAR(100),
    embedding   vector(1536),    -- Titan Embeddings v2 output
    metadata    JSONB DEFAULT '{}',
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- HNSW index for fast similarity search
CREATE INDEX idx_knowledge_embedding
    ON knowledge_documents
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

-- Chat sessions table
CREATE TABLE chat_sessions (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     VARCHAR(255),
    started_at  TIMESTAMPTZ DEFAULT NOW(),
    ended_at    TIMESTAMPTZ,
    metadata    JSONB DEFAULT '{}'
);

-- Chat messages table
CREATE TABLE chat_messages (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id  UUID REFERENCES chat_sessions(id),
    role        VARCHAR(20) NOT NULL, -- 'user' or 'assistant'
    content     TEXT NOT NULL,
    tokens_used INTEGER,
    latency_ms  INTEGER,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);
```

---

## Analytics Pipeline

### Event-Driven Sentiment Analysis

```mermaid
sequenceDiagram
    participant CS as Chat Service
    participant RQ as Redis Queue
    participant KEDA as KEDA Scaler
    participant AS as Analytics Service
    participant BD as Bedrock (Claude)
    participant PG as Aurora PostgreSQL
    participant S3 as S3 Data Lake

    CS->>RQ: Push message to analytics:queue
    
    Note over KEDA: Monitor queue depth
    KEDA->>KEDA: Queue depth > threshold?
    KEDA->>AS: Scale up analytics pods

    AS->>RQ: Consume message batch
    
    par Sentiment Analysis
        AS->>BD: Analyze sentiment (Claude 3.5)
        BD-->>AS: Sentiment score + labels
        AS->>PG: Store sentiment metrics
    and Transcript Archival
        AS->>S3: Archive full transcript
        Note over S3: Lifecycle: Standard → IA (30d) → Glacier (90d)
    end
    
    AS->>PG: Update aggregated CSAT metrics
```

### Metrics Aggregation Flow

```mermaid
graph LR
    RAW["Raw Messages"] --> SENT["Sentiment<br>Analysis"]
    SENT --> SCORE["Score<br>-1.0 to 1.0"]
    SCORE --> AGG["Aggregate by<br>Hour/Day/Week"]
    AGG --> CSAT["CSAT Dashboard<br>Metrics API"]
    
    SCORE --> LABELS["Labels<br>positive/neutral/negative"]
    LABELS --> DIST["Distribution<br>Analysis"]
    DIST --> CSAT

    style SENT fill:#ff9900,color:#fff
    style CSAT fill:#2ecc71,color:#fff
```

### Analytics API Response Format

```json
{
  "period": "2024-01-15",
  "metrics": {
    "total_conversations": 1247,
    "avg_sentiment_score": 0.72,
    "sentiment_distribution": {
      "positive": 0.65,
      "neutral": 0.22,
      "negative": 0.13
    },
    "avg_response_time_ms": 1850,
    "avg_messages_per_session": 6.3,
    "resolution_rate": 0.84
  }
}
```

---

## Session Management

### Redis Session State

```mermaid
graph TB
    subgraph "Redis Data Structures"
        SESS["session:{id}<br>Hash: user_id, started_at, state"]
        HIST["session:{id}:history<br>List: last 10 messages"]
        CACHE["cache:{query_hash}<br>String: cached response<br>TTL: 3600s"]
        QUEUE["analytics:queue<br>List: pending messages"]
    end

    subgraph "TTL Policies"
        SESS --> T1["24 hours"]
        HIST --> T2["24 hours"]
        CACHE --> T3["1 hour"]
        QUEUE --> T4["No TTL<br>(consumed by workers)"]
    end

    style SESS fill:#dc382c,color:#fff
    style HIST fill:#dc382c,color:#fff
    style CACHE fill:#dc382c,color:#fff
    style QUEUE fill:#dc382c,color:#fff
```

### Session Lifecycle

| Event | Redis Action | PostgreSQL Action |
|-------|-------------|-------------------|
| Connection open | Create `session:{id}` hash | INSERT into `chat_sessions` |
| Message received | Append to `session:{id}:history` | INSERT into `chat_messages` |
| Response generated | Set `cache:{hash}` with TTL | Update `tokens_used`, `latency_ms` |
| Connection close | Set `state=ended` | UPDATE `ended_at` |
| Session expired | Auto-deleted by TTL | Retained for analytics |

---

## Data Retention & Lifecycle

### S3 Lifecycle Policies

```mermaid
graph LR
    UP["Upload<br>Transcript/Report"] --> STD["S3 Standard<br>Day 0-30"]
    STD --> IA["S3 Intelligent-Tiering<br>Day 30-90"]
    IA --> GLACIER["S3 Glacier<br>Day 90-365"]
    GLACIER --> DELETE["Delete<br>Day 365+"]

    style STD fill:#ff9900,color:#fff
    style IA fill:#f39c12,color:#fff
    style GLACIER fill:#3498db,color:#fff
    style DELETE fill:#e74c3c,color:#fff
```

### Retention Summary

| Data Type | Storage | Hot Period | Warm Period | Cold/Archive | Deletion |
|-----------|---------|-----------|-------------|--------------|----------|
| Chat sessions | Aurora | 90 days | — | — | Soft delete |
| Chat messages | Aurora | 90 days | — | — | Soft delete |
| Knowledge docs | Aurora + pgvector | Indefinite | — | — | Manual |
| Transcripts | S3 | 30 days | 30-90 days | 90-365 days | 365 days |
| Sentiment reports | S3 | 30 days | 30-90 days | 90-365 days | 365 days |
| Redis sessions | ElastiCache | 24 hours | — | — | TTL expiry |
| Redis cache | ElastiCache | 1 hour | — | — | TTL expiry |
| CloudFront logs | S3 | 30 days | — | — | 90 days |
