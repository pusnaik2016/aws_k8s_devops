# Architecture — OmniPresenseAI

> Comprehensive architecture documentation for the Omnichannel AI-Powered Customer Support & Analytics Platform.

---

## System Overview

OmniPresenseAI is a **3-layer cloud-native architecture** built on AWS, designed for real-time AI-powered customer support with built-in analytics.

| Layer | Components | Purpose |
|-------|-----------|---------|
| **Edge & Routing** | Route 53, CloudFront, API Gateway, ALB | Traffic management, SSL, caching |
| **Compute & AI** | EKS, Bedrock (Claude 3.5 Sonnet), KEDA | Microservice orchestration, AI inference |
| **Storage & Caching** | Aurora PostgreSQL (pgvector), ElastiCache Redis, S3 | Persistence, vector search, caching |

---

## High-Level Architecture

```mermaid
graph TB
    subgraph "Edge and Routing Layer"
        USER["User Browser"]
        R53["Route 53"]
        CF["CloudFront CDN"]
        S3FE["S3 Frontend"]
        APIGW["API Gateway<br>WebSocket + REST"]
    end

    subgraph "Compute and AI Layer"
        ALB["Application Load Balancer"]
        subgraph "EKS Cluster"
            CHAT["Chat Service<br>FastAPI"]
            ANALYTICS["Analytics Service<br>Sentiment"]
            KEDA_S["KEDA Scaler"]
        end
        BEDROCK["Bedrock<br>Claude 3.5 Sonnet"]
        TITAN["Bedrock<br>Titan Embeddings"]
    end

    subgraph "Storage and Caching Layer"
        REDIS["ElastiCache Redis"]
        AURORA["Aurora PostgreSQL<br>pgvector"]
        S3DATA["S3 Data Lake"]
    end

    USER --> R53 --> CF
    CF --> S3FE
    CF --> APIGW --> ALB
    ALB --> CHAT
    ALB --> ANALYTICS
    CHAT --> BEDROCK
    CHAT --> TITAN
    CHAT --> REDIS
    CHAT --> AURORA
    ANALYTICS --> BEDROCK
    ANALYTICS --> S3DATA
    ANALYTICS --> AURORA
    KEDA_S --> ANALYTICS

    style BEDROCK fill:#ff9900,color:#fff
    style TITAN fill:#ff9900,color:#fff
    style AURORA fill:#3b48cc,color:#fff
    style REDIS fill:#dc382c,color:#fff
```

---

## Data Flow — Chat Request Lifecycle

```mermaid
graph LR
    MSG["User Message"] --> WS["API Gateway<br>WebSocket"]
    WS --> FAST["Chat Service<br>FastAPI"]
    FAST --> CHK{Redis Cache?}
    CHK -->|Hit| RET["Return Cached"]
    CHK -->|Miss| EMB["Titan Embedding"]
    EMB --> PGV["pgvector Search"]
    PGV --> LLM["Claude 3.5<br>Generate Response"]
    LLM --> SAVE["Cache in Redis"]
    SAVE --> RESP["Stream to User"]
    LLM --> Q["Analytics Queue"]
    Q --> SENT["Sentiment Analysis"]
    SENT --> S3["Archive S3"]

    style RET fill:#2ecc71,color:#fff
    style LLM fill:#ff9900,color:#fff
```

---

## Security Architecture

```mermaid
graph TB
    subgraph "Zero-Trust CI/CD"
        GH["GitHub Actions"] --> OIDC["OIDC Federation"]
        OIDC --> STS["AWS STS Temp Creds"]
    end

    subgraph "Network Isolation"
        PUB["Public Subnets<br>ALB, NAT"]
        PRIV["Private Subnets<br>EKS, Aurora, Redis"]
        PUB --> PRIV
    end

    subgraph "Identity"
        IRSA["IRSA<br>Pod-Level IAM"]
        KMS["KMS Encryption"]
        SSM["SSM SecureString"]
    end

    STS --> PUB
    IRSA --> KMS
    IRSA --> SSM

    style OIDC fill:#2ecc71,color:#fff
    style PRIV fill:#3b48cc,color:#fff
    style KMS fill:#e74c3c,color:#fff
```

---

## AWS Service Inventory

| Service | Resource | Purpose | Encryption |
|---------|----------|---------|-----------|
| VPC | 10.0.0.0/16, 6 subnets, NAT | Network isolation | N/A |
| Route 53 | Hosted zone | DNS management | N/A |
| CloudFront | Distribution + OAC | CDN, SSL termination | TLS 1.3 |
| API Gateway | WebSocket + HTTP API | Traffic management | TLS |
| EKS | v1.29, Managed nodes | Container orchestration | KMS (secrets) |
| Bedrock | Claude 3.5 Sonnet | Conversational AI | AWS managed |
| Bedrock | Titan Embeddings v2 | Vector embeddings | AWS managed |
| Aurora | PostgreSQL 15.4 Serverless v2 | pgvector + transactional | KMS |
| ElastiCache | Redis 7.1, 2-node | Session + LLM cache | KMS + TLS |
| S3 | 2 buckets (frontend + transcripts) | Static assets + archival | KMS |
| KMS | 3 keys (EKS, Aurora, S3) | Encryption at rest | N/A |
| IAM | OIDC + IRSA + service roles | Identity management | N/A |

---

## Module Dependency Graph

```mermaid
graph LR
    NET["networking"] --> SEC["security"]
    NET --> COMP["compute"]
    NET --> DB["database"]
    NET --> CDN["ai_cdn"]
    SEC --> COMP
    SEC --> DB
    SEC --> CDN

    style NET fill:#58a6ff,color:#fff
    style SEC fill:#e74c3c,color:#fff
    style COMP fill:#2ecc71,color:#fff
    style DB fill:#3b48cc,color:#fff
    style CDN fill:#8c4fff,color:#fff
```

| Module | Depends On | Resources Created |
|--------|-----------|-------------------|
| networking | — | VPC, subnets, NAT, Route53 |
| security | networking | IAM, OIDC, KMS, SGs, SSM |
| compute | networking, security | EKS, node groups, IRSA, ALB controller |
| database | networking, security | Aurora PostgreSQL, ElastiCache Redis |
| ai_cdn | networking, security | CloudFront, S3, API Gateway |
