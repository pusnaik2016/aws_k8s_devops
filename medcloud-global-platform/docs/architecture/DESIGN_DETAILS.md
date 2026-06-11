# MedCloud Global — Design Details

## Table of Contents

1. [Microservices Design](#1-microservices-design)
2. [Database Design & Data Model](#2-database-design--data-model)
3. [API Design Patterns](#3-api-design-patterns)
4. [Cross-Cloud Communication Design](#4-cross-cloud-communication-design)
5. [AI/ML Pipeline Design](#5-aiml-pipeline-design)
6. [Security Design Patterns](#6-security-design-patterns)
7. [Observability Design](#7-observability-design)
8. [FinOps & Cost Management](#8-finops--cost-management)
9. [Application Build & Container Design](#9-application-build--container-design)

---

## 1. Microservices Design

### 1.1 Service Catalog

| Service | Cloud | Language/Framework | Purpose | Data Store | Compliance |
|---------|-------|-------------------|---------|------------|------------|
| **storefront-api** | AWS EKS | Java 21 / Spring Boot 3.3 | E-commerce frontend API, product catalog, search | Aurora PostgreSQL, DynamoDB, ElastiCache | PCI-DSS |
| **order-service** | AWS EKS | Java 21 / Spring Boot 3.3 | Order processing, payment orchestration, inventory | Aurora PostgreSQL | PCI-DSS |
| **patient-service** | Azure AKS | Java 21 / Spring Boot 3.3 | Patient profile CRUD, consent management, EHR integration | Cosmos DB (MongoDB) | HIPAA, GDPR |
| **imaging-service** | Azure AKS | Python 3.12 / FastAPI | DICOM image upload, AI Vision analysis, report generation | Blob Storage, Azure AI Vision | HIPAA |
| **ai-gateway** | GCP GKE | Python 3.12 / FastAPI | ML inference gateway, fraud detection, recommendations | BigQuery, Vertex AI Feature Store | De-identified |
| **notification-service** | AWS EKS | Java 21 / Spring Boot 3.3 | Multi-channel notifications (email, SMS, push) | SNS, SES | PCI-DSS, HIPAA |

### 1.2 Service Interaction Matrix

```
                    ┌──────────┐
                    │ External │
                    │ Client   │
                    └────┬─────┘
                         │ HTTPS
                    ┌────▼─────┐
                    │Storefront│
                    │  API     │
                    └────┬─────┘
                         │
           ┌─────────────┼─────────────┐
           │             │             │
     ┌─────▼─────┐ ┌────▼─────┐ ┌────▼──────┐
     │  Order    │ │ Patient  │ │   AI      │
     │  Service  │ │ Service  │ │  Gateway  │
     └─────┬─────┘ └────┬─────┘ └────┬──────┘
           │             │             │
     ┌─────▼─────┐ ┌────▼─────┐      │
     │Notification│ │ Imaging  │◄─────┘
     │  Service  │ │ Service  │
     └───────────┘ └──────────┘

Communication: All service-to-service via Istio mesh (mTLS)
Cross-cloud:   Istio east-west gateway (port 15443)
```

### 1.3 Service Design Principles

1. **Single Responsibility:** Each service owns exactly one business domain
2. **Database per Service:** No shared databases — data exchange via APIs
3. **Event-Driven Where Possible:** Order events → SNS/SQS → patient-service sync
4. **Circuit Breaker Pattern:** Istio DestinationRule with outlierDetection
5. **Saga Pattern:** Order processing uses choreography-based saga across AWS↔Azure
6. **Idempotency:** All write endpoints include idempotency keys

---

## 2. Database Design & Data Model

### 2.1 Aurora PostgreSQL (AWS) — E-Commerce Schema

```sql
-- Partitioned by order date for query performance
CREATE TABLE orders (
    order_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id     UUID NOT NULL,                    -- FK to customer table
    order_date      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status          TEXT NOT NULL CHECK (status IN (
        'pending', 'confirmed', 'processing', 
        'shipped', 'delivered', 'cancelled', 'refunded'
    )),
    total_amount    DECIMAL(12,2) NOT NULL,
    currency        CHAR(3) NOT NULL DEFAULT 'USD',
    payment_method  TEXT,                             -- Tokenized (PCI-DSS)
    payment_token   TEXT,                             -- Payment gateway token
    shipping_address JSONB,                           -- Encrypted at column level
    is_prescription BOOLEAN DEFAULT FALSE,            -- Links to patient-service
    patient_id      UUID,                             -- Cross-cloud reference
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
) PARTITION BY RANGE (order_date);

-- Monthly partitions
CREATE TABLE orders_2024_01 PARTITION OF orders
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

-- Products catalog
CREATE TABLE products (
    product_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sku             TEXT UNIQUE NOT NULL,
    name            TEXT NOT NULL,
    category        TEXT NOT NULL,
    description     TEXT,
    price           DECIMAL(10,2) NOT NULL,
    currency        CHAR(3) DEFAULT 'USD',
    requires_prescription BOOLEAN DEFAULT FALSE,
    stock_quantity  INTEGER NOT NULL DEFAULT 0,
    metadata        JSONB,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Customers (PII encrypted, PCI-DSS tokenized)
CREATE TABLE customers (
    customer_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email_hash      TEXT NOT NULL,                    -- SHA-256 hash for lookup
    name_encrypted  BYTEA,                            -- AES-256 encrypted
    phone_encrypted BYTEA,                            -- AES-256 encrypted
    address_encrypted BYTEA,                          -- AES-256 encrypted
    payment_tokens  TEXT[],                            -- Stripe/Adyen tokens
    consent_flags   JSONB DEFAULT '{}',               -- GDPR consent tracking
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    gdpr_deletion_requested_at TIMESTAMPTZ            -- GDPR right to erasure
);

-- Row-Level Security for multi-tenancy
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON orders
    USING (customer_id = current_setting('app.current_customer_id')::UUID);
```

### 2.2 Cosmos DB (Azure) — Patient Profile Schema

```json
// Collection: patients (shard key: region)
{
    "_id": "patient-uuid-12345",
    "patient_id": "PAT-2024-00001",
    "region": "us-east",
    "demographics": {
        "first_name": "encrypted:AES256:...",
        "last_name": "encrypted:AES256:...",
        "date_of_birth": "encrypted:AES256:...",
        "gender": "M",
        "blood_type": "O+"
    },
    "contact": {
        "email_hash": "sha256:...",
        "phone_encrypted": "encrypted:AES256:..."
    },
    "insurance": {
        "provider": "Blue Cross",
        "policy_number": "encrypted:AES256:...",
        "group_number": "encrypted:AES256:..."
    },
    "consent": {
        "data_processing": true,
        "data_sharing_analytics": true,
        "marketing": false,
        "consent_date": "2024-01-15T00:00:00Z",
        "gdpr_applicable": true
    },
    "linked_orders": ["order-uuid-aws-1", "order-uuid-aws-2"],
    "medical_record_refs": ["rec-uuid-1", "rec-uuid-2"],
    "created_at": "2024-01-15T10:30:00Z",
    "updated_at": "2024-06-01T14:22:00Z",
    "_ts": 1717246920,
    "ttl": -1
}

// Collection: medical-records (shard key: patient_id)
{
    "_id": "rec-uuid-1",
    "patient_id": "PAT-2024-00001",
    "record_type": "prescription",
    "provider": {
        "name": "Dr. Smith",
        "npi": "1234567890",
        "facility": "City Hospital"
    },
    "clinical_data": {
        "diagnosis_codes": ["ICD-10:J06.9"],
        "medications": [
            {
                "name": "Amoxicillin",
                "dosage": "500mg",
                "frequency": "3x daily",
                "duration_days": 10,
                "ndc": "0093-3109-01"
            }
        ],
        "notes_encrypted": "encrypted:AES256:..."
    },
    "ai_analysis": {
        "openai_summary": "Patient presents with...",
        "entities_extracted": ["URI", "bacterial infection"],
        "confidence_score": 0.94,
        "model_version": "gpt-4o-2024-05-13"
    },
    "imaging_refs": ["img-uuid-blob-1"],
    "created_at": "2024-06-01T14:00:00Z"
}
```

### 2.3 BigQuery (GCP) — Analytics Schema

```sql
-- De-identified analytics fact table
-- ALL PII/PHI stripped by Cloud DLP before ingestion
CREATE TABLE ecommerce_transactions.orders (
    order_id            STRING NOT NULL,
    customer_id         STRING NOT NULL,   -- Tokenized (FPE)
    order_date          TIMESTAMP NOT NULL,
    region              STRING NOT NULL,
    product_category    STRING NOT NULL,
    product_id          STRING NOT NULL,
    quantity            INT64 NOT NULL,
    unit_price          FLOAT64 NOT NULL,
    total_amount        FLOAT64 NOT NULL,
    currency            STRING NOT NULL,
    payment_method      STRING,            -- "[REDACTED]" by DLP
    payment_status      STRING NOT NULL,
    shipping_country    STRING,
    is_prescription     BOOL NOT NULL
)
PARTITION BY DATE(order_date)
CLUSTER BY region, product_category, payment_status;

-- ML Feature table for fraud detection
CREATE TABLE ecommerce_transactions.fraud_features (
    customer_id         STRING NOT NULL,   -- Tokenized
    feature_date        DATE NOT NULL,
    total_orders_30d    INT64,
    total_spend_30d     FLOAT64,
    avg_order_value     FLOAT64,
    unique_products     INT64,
    unique_categories   INT64,
    max_single_order    FLOAT64,
    shipping_countries  INT64,
    prescription_ratio  FLOAT64,
    time_since_first    INT64,             -- Days
    is_fraud_label      BOOL               -- Training label
)
PARTITION BY feature_date;
```

---

## 3. API Design Patterns

### 3.1 API Gateway Pattern

```
External Client
      │
      ▼
┌──────────────────────────┐
│   API Gateway (Istio)    │
│   ├─ Rate limiting       │
│   ├─ JWT validation      │
│   ├─ Request routing     │
│   ├─ Request/Response    │
│   │  transformation      │
│   └─ Access logging      │
└──────────┬───────────────┘
           │
    ┌──────┴──────┐
    │   Backend   │
    │   Service   │
    └─────────────┘
```

### 3.2 API Versioning

```
Base URL:  https://api.medcloud.example.com/v1/
Versioned: /v1/orders, /v1/patients, /v1/images
Headers:   Accept: application/json
           X-Request-ID: uuid (for distributed tracing)
           X-Correlation-ID: uuid (for cross-cloud tracing)
```

### 3.3 Error Response Standard

```json
{
    "error": {
        "code": "PATIENT_NOT_FOUND",
        "message": "Patient with ID PAT-2024-00001 not found",
        "details": [],
        "request_id": "req-uuid-12345",
        "timestamp": "2024-06-01T14:00:00Z"
    }
}
```

---

## 4. Cross-Cloud Communication Design

### 4.1 Istio Multi-Cluster Mesh

```
MESH TOPOLOGY: Multi-Primary on Different Networks

┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│   AWS EKS        │     │   Azure AKS      │     │   GCP GKE        │
│   ┌────────────┐ │     │   ┌────────────┐ │     │   ┌────────────┐ │
│   │  istiod    │ │     │   │  istiod    │ │     │   │  istiod    │ │
│   │ (control)  │ │     │   │ (control)  │ │     │   │ (control)  │ │
│   └────────────┘ │     │   └────────────┘ │     │   └────────────┘ │
│   ┌────────────┐ │     │   ┌────────────┐ │     │   ┌────────────┐ │
│   │ East-West  │◄┼─────┼──▶│ East-West  │◄┼─────┼──▶│ East-West  │ │
│   │ Gateway    │ │ mTLS│   │ Gateway    │ │ mTLS│   │ Gateway    │ │
│   │ :15443     │ │     │   │ :15443     │ │     │   │ :15443     │ │
│   └────────────┘ │     │   └────────────┘ │     │   └────────────┘ │
│                  │     │                  │     │                  │
│   network:       │     │   network:       │     │   network:       │
│   network-aws    │     │   network-azure  │     │   network-gcp    │
│   meshID:        │     │   meshID:        │     │   meshID:        │
│   medcloud-mesh  │     │   medcloud-mesh  │     │   medcloud-mesh  │
└──────────────────┘     └──────────────────┘     └──────────────────┘

All 3 clusters share the same meshID but different networks.
Cross-cluster discovery via Istio remote secrets.
```

### 4.2 Cross-Cloud Service Discovery

```yaml
# Example: AWS EKS discovering Azure AKS services
# Remote secret installed in AWS EKS cluster
apiVersion: v1
kind: Secret
metadata:
  name: istio-remote-secret-azure-aks
  namespace: istio-system
  labels:
    istio/multiCluster: "true"
  annotations:
    networking.istio.io/cluster: azure-aks
type: Opaque
data:
  azure-aks: <base64-encoded-kubeconfig>
```

---

## 5. AI/ML Pipeline Design

### 5.1 Data Pipeline (Azure → GCP)

```
MEDICAL DATA ANALYTICS PIPELINE:

  Azure (Source)                            GCP (Destination)
  ┌──────────┐                             ┌──────────────┐
  │ Cosmos DB│                             │ BigQuery     │
  │ (PHI)    │                             │ (Anonymized) │
  └────┬─────┘                             └──────▲───────┘
       │                                          │
       ▼                                          │
  ┌──────────┐    ┌──────────┐    ┌──────────┐   │
  │ Change   │───▶│ Event    │───▶│ Cloud    │───┘
  │ Feed     │    │ Hubs     │    │ DLP      │
  │ (CDC)    │    │          │    │ (De-ID)  │
  └──────────┘    └──────────┘    └──────────┘

  DLP Operations:
  1. PERSON_NAME    → FPE (Format-Preserving Encryption)
  2. PHONE_NUMBER   → [REDACTED]
  3. EMAIL_ADDRESS  → [REDACTED]
  4. SSN            → [REDACTED]
  5. MRN            → [REDACTED]
  6. CREDIT_CARD    → [REDACTED]
  7. DATE_OF_BIRTH  → Generalized to year
```

### 5.2 ML Model Lifecycle

```
MODEL LIFECYCLE (Vertex AI):

  ┌─────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
  │ Feature │───▶│ Training │───▶│ Evaluation│───▶│ Registry │
  │ Store   │    │ Pipeline │    │ Metrics   │    │ (Model)  │
  └─────────┘    └──────────┘    └──────────┘    └────┬─────┘
                                                       │
                                              ┌────────▼────────┐
                                              │   Deployment     │
                                              │   (Endpoint)     │
                                              │   A/B Testing    │
                                              │   Shadow Mode    │
                                              └────────┬────────┘
                                                       │
                                              ┌────────▼────────┐
                                              │   Monitoring     │
                                              │   Data Drift     │
                                              │   Model Decay    │
                                              │   Retrain Trigger│
                                              └─────────────────┘

  MODELS:
  1. Fraud Detection    — TabNet on BigQuery features → real-time scoring
  2. Product Recommend  — Two-Tower model on interaction data → batch serving
  3. Clinical NLP       — Azure OpenAI GPT-4o → medical note summarization
  4. Image Analysis     — Azure AI Vision → DICOM anomaly detection
```

---

## 6. Security Design Patterns

### 6.1 Encryption Strategy

| Layer | Mechanism | Key Management | Rotation |
|-------|-----------|---------------|----------|
| **TLS 1.3** | All services, all clouds | Cloud-managed certificates (ACM/App Service/GCP Managed) | Auto-rotate |
| **mTLS** | Istio mesh (STRICT mode) | Istio CA (citadel) | Auto-rotate 24hr |
| **At-Rest (Storage)** | AES-256-GCM | CMK per cloud (KMS/Key Vault/Cloud KMS) | 90-day rotation |
| **At-Rest (Database)** | AES-256 TDE | CMK per database | 90-day rotation |
| **Column-Level** | AES-256-CBC | Application-managed (Key Vault) | Annual |
| **Tokenization** | FPE (PCI tokens) | Payment gateway managed | Per-transaction |

### 6.2 Secrets Management Flow

```
┌──────────────────────────────────────────────────────────────────┐
│                    SECRETS MANAGEMENT                             │
│                                                                   │
│  AWS:   Secrets Manager → IRSA → Pod                            │
│         KMS encrypts all secrets at rest                         │
│                                                                   │
│  Azure: Key Vault → CSI Driver → Pod mount                      │
│         HSM-backed keys (Premium SKU)                            │
│         Auto-rotation every 90 days                              │
│                                                                   │
│  GCP:   Secret Manager → Workload Identity → Pod                │
│         Cloud KMS envelope encryption                            │
│                                                                   │
│  CROSS-CLOUD: HashiCorp Vault (Enterprise) for unified secrets  │
│               when services need credentials from another cloud  │
└──────────────────────────────────────────────────────────────────┘
```

---

## 7. Observability Design

### 7.1 Observability Stack

```
THREE PILLARS OF OBSERVABILITY:

┌──────────────────────────────────────────────────────────────────┐
│  METRICS (Prometheus + Grafana)                                   │
│  ├── Infrastructure: node CPU/memory/disk, pod resource usage    │
│  ├── Application: request rate, error rate, duration (RED)       │
│  ├── Business: orders/min, revenue, cart abandonment rate        │
│  └── SLIs/SLOs: availability, latency p99, error budget         │
│                                                                   │
│  LOGGING (Fluentd → Cloud-native sinks)                          │
│  ├── AWS → CloudWatch Logs (encrypted with KMS)                  │
│  ├── Azure → Log Analytics Workspace                             │
│  ├── GCP → Cloud Logging                                         │
│  └── Cross-cloud → Grafana Loki (unified view)                  │
│                                                                   │
│  TRACING (Istio + Jaeger/Tempo)                                  │
│  ├── Distributed traces across all 3 clouds                     │
│  ├── 100% sampling in dev, 10% in prod                          │
│  ├── Trace context propagation via W3C headers                  │
│  └── Cross-cloud correlation via X-Correlation-ID               │
└──────────────────────────────────────────────────────────────────┘
```

### 7.2 Alerting Strategy

| Severity | Response Time | Channel | Example |
|----------|-------------|---------|---------|
| **P1 — Critical** | 5 min | PagerDuty + Slack #sre-critical | Service down, data breach indicator |
| **P2 — High** | 30 min | PagerDuty + Slack #sre-alerts | Error rate > 5%, latency p99 > 2s |
| **P3 — Medium** | 4 hr | Slack #platform-alerts | Pod restart loops, certificate expiry < 7d |
| **P4 — Low** | Next business day | Slack #platform-info | Resource utilization > 80%, non-critical CVE |

---

## 8. FinOps & Cost Management

### 8.1 Cost Optimization Strategy

| Strategy | AWS | Azure | GCP |
|----------|-----|-------|-----|
| **Reserved/Committed** | Savings Plans (1yr) | Reserved VM Instances | CUDs (1yr) |
| **Spot/Preemptible** | EKS Spot node groups (dev) | AKS Spot pools (dev) | GKE Preemptible (dev) |
| **Right-Sizing** | Compute Optimizer recommendations | Azure Advisor | GKE cost management |
| **Storage Tiering** | S3 Intelligent Tiering | Cool/Archive tiers | Nearline/Coldline lifecycle |
| **Scale-to-Zero** | Karpenter for EKS | KEDA for AKS | GKE Autopilot |

### 8.2 Estimated Monthly Costs (Production)

| Component | AWS | Azure | GCP | Total |
|-----------|-----|-------|-----|-------|
| **Compute (K8s)** | $2,500 | $2,000 | $1,800 | $6,300 |
| **Databases** | $1,800 | $1,200 | $800 | $3,800 |
| **Networking** | $500 | $400 | $300 | $1,200 |
| **AI/ML Services** | — | $1,500 | $1,000 | $2,500 |
| **Storage** | $200 | $300 | $200 | $700 |
| **Security/Monitoring** | $400 | $300 | $200 | $900 |
| **Total** | **$5,400** | **$5,700** | **$4,300** | **$15,400** |

> *Note: Estimates for mid-scale production. Dev environments use spot/preemptible instances, reducing costs by ~60%.*

---

## 9. Application Build & Container Design

### 9.1 Dockerfile Strategy

All services use multi-stage builds to minimize image size and attack surface:

| Service | Base Image (Build) | Base Image (Runtime) | User | Image Size |
|---------|-------------------|---------------------|------|------------|
| **storefront-api** | `eclipse-temurin:21-jdk-alpine` | `eclipse-temurin:21-jre-alpine` | `medcloud` (non-root) | ~180MB |
| **order-service** | `eclipse-temurin:21-jdk-alpine` | `eclipse-temurin:21-jre-alpine` | `medcloud` (non-root) | ~175MB |
| **patient-service** | `eclipse-temurin:21-jdk-alpine` | `eclipse-temurin:21-jre-alpine` | `medcloud` (non-root) | ~185MB |
| **imaging-service** | `python:3.12-slim` | `python:3.12-slim` | `medcloud` (non-root) | ~220MB |
| **ai-gateway** | `python:3.12-slim` | `python:3.12-slim` | `medcloud` (non-root) | ~250MB |
| **notification-service** | `eclipse-temurin:21-jdk-alpine` | `eclipse-temurin:21-jre-alpine` | `medcloud` (non-root) | ~170MB |

### 9.2 Java/Spring Boot Build Pattern

```
MULTI-STAGE DOCKER BUILD (Java services):

  Stage 1: BUILD (eclipse-temurin:21-jdk-alpine)
  ├── Copy pom.xml → mvn dependency:go-offline (cached layer)
  ├── Copy src/ → mvn clean package -DskipTests
  └── Extract Spring Boot layers:
      ├── dependencies/              (rarely changes → cached)
      ├── spring-boot-loader/        (rarely changes → cached)
      ├── snapshot-dependencies/     (occasionally changes)
      └── application/              (changes every build)

  Stage 2: RUNTIME (eclipse-temurin:21-jre-alpine)
  ├── Non-root user: medcloud:medcloud
  ├── COPY layers in order (optimal Docker caching)
  ├── JVM flags:
  │   ├── -XX:+UseContainerSupport (respect cgroup limits)
  │   ├── -XX:MaxRAMPercentage=75.0 (leave headroom)
  │   └── -Djava.security.egd=file:/dev/urandom
  ├── HEALTHCHECK: curl -f http://localhost:8080/health/live
  └── LABEL: OCI metadata + compliance tags (hipaa, pci-dss)
```

### 9.3 Maven POM Structure

```
Maven Dependencies (storefront-api):

  Spring Boot 3.3 (Java 21)
  ├── spring-boot-starter-web              (REST API)
  ├── spring-boot-starter-data-jpa         (Aurora PostgreSQL)
  ├── spring-boot-starter-data-redis       (ElastiCache)
  ├── spring-boot-starter-security         (Authentication)
  ├── spring-boot-starter-oauth2-resource-server (JWT/OAuth2)
  ├── spring-boot-starter-actuator         (Health + Metrics)
  ├── spring-boot-starter-validation       (Input validation)
  ├── micrometer-registry-prometheus       (Prometheus metrics)
  ├── micrometer-tracing-bridge-otel       (OpenTelemetry traces)
  ├── aws-sdk-v2 (dynamodb-enhanced, s3)   (AWS services)
  ├── postgresql                           (JDBC driver)
  └── lombok                               (boilerplate reduction)

  Testing:
  ├── spring-boot-starter-test             (JUnit 5, Mockito)
  ├── testcontainers-postgresql            (Integration tests)
  └── jacoco-maven-plugin                  (70% min coverage)
```

### 9.4 Health Check Endpoints

All services expose standard health endpoints consumed by K8s probes and Docker HEALTHCHECK:

| Endpoint | Purpose | K8s Probe | Interval |
|----------|---------|-----------|----------|
| `/health/live` | Liveness — is the process alive? | `livenessProbe` | 15s |
| `/health/ready` | Readiness — can it serve traffic? | `readinessProbe` | 10s |
| `/health/startup` | Startup — has it finished initializing? | `startupProbe` | 5s (max 60 attempts) |
| `/metrics` | Prometheus metrics (RED + JVM) | N/A (Prometheus scrape) | 15s |

---

**Document Version:** 2.0 | **Last Updated:** 2026-06-11 | **Author:** Pushparaj Naik | **Classification:** Internal — Confidential
