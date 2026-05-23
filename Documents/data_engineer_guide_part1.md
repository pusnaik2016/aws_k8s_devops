# Data Engineer Comprehensive Guide — Part 1
## GCP · Python · Kafka

> **Target Role**: Data Engineer  
> **Tech Stack**: GCP, Python, Kafka, Apache Beam, Airflow, Kubernetes  
> **Guide Structure**: Part 1 (this file) → Part 2 (Apache Beam, Airflow) → Part 3 (Kubernetes, Architecture, Interview Q&A)

---

# 1. What Is Expected of a Data Engineer?

## 1.1 The Role in a Nutshell

A Data Engineer **designs, builds, and maintains** the infrastructure and pipelines that move data from source systems to destinations where it can be analyzed. Think of yourself as the **plumber of the data world** — data scientists and analysts can only do their job if you deliver clean, reliable, timely data.

## 1.2 Core Responsibilities

| Area | What You Do |
|---|---|
| **Data Ingestion** | Pull data from APIs, databases, files, streams (Kafka), IoT devices |
| **Data Transformation** | Clean, enrich, deduplicate, aggregate (ETL/ELT) |
| **Data Storage** | Design schemas, choose the right storage (BigQuery, Cloud Storage, Bigtable) |
| **Pipeline Orchestration** | Schedule & monitor workflows (Airflow) |
| **Stream Processing** | Process real-time events (Kafka + Apache Beam) |
| **Data Quality** | Validate, test, and monitor data freshness and accuracy |
| **Infrastructure** | Deploy and scale pipeline infra on Kubernetes/GKE |
| **Security & Governance** | Encryption, access control, data lineage, compliance |

## 1.3 What Interviewers Expect (This Stack)

```
┌─────────────────────────────────────────────────────────┐
│                  INTERVIEWER EXPECTATIONS                │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  GCP ──────────► BigQuery, Dataflow, Pub/Sub, GCS,     │
│                  Cloud Composer, GKE, IAM               │
│                                                         │
│  Python ───────► pandas, PySpark concepts, Beam SDK,   │
│                  API integrations, testing              │
│                                                         │
│  Kafka ────────► Producer/Consumer, Topics, Partitions,│
│                  Consumer Groups, Exactly-once semantics│
│                                                         │
│  Apache Beam ──► Unified batch+stream, PCollections,   │
│                  Transforms, Windowing, Watermarks      │
│                                                         │
│  Airflow ──────► DAGs, Operators, Sensors, XComs,      │
│                  scheduling, retry/backfill             │
│                                                         │
│  Kubernetes ───► Pods, Deployments, Services, GKE,     │
│                  running pipelines on K8s               │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## 1.4 Day-in-the-Life Scenarios

**Morning**: Check Airflow dashboard → a DAG failed overnight. Investigate logs, find a schema change in source API. Fix the transformation logic, backfill the missed runs.

**Midday**: Design a new streaming pipeline — Kafka ingests clickstream events → Apache Beam (on Dataflow) enriches them with user profiles from BigQuery → writes aggregated metrics to a dashboard table.

**Afternoon**: Review a PR from a teammate adding a new data source. Check for idempotency, error handling, and data quality checks. Deploy the updated pipeline to GKE.

---

# 2. GCP for Data Engineering

## 2.1 Key GCP Services You Must Know

### Storage Layer

| Service | Type | Use Case | Key Feature |
|---|---|---|---|
| **Cloud Storage (GCS)** | Object Store | Raw files, data lake staging | Lifecycle policies, nearline/coldline tiers |
| **BigQuery** | Serverless Data Warehouse | Analytics, SQL queries on PB-scale data | Columnar storage, auto-scaling, ML built-in |
| **Cloud SQL** | Managed RDBMS | Transactional data (PostgreSQL/MySQL) | Automated backups, HA replicas |
| **Cloud Spanner** | Global relational DB | Global transactions at scale | Horizontal scaling + ACID |
| **Bigtable** | Wide-column NoSQL | High-throughput, low-latency (IoT, time-series) | HBase API compatible |
| **Firestore** | Document NoSQL | App backends, semi-structured data | Real-time sync |

### Compute & Processing Layer

| Service | What It Does | Maps To |
|---|---|---|
| **Dataflow** | Managed Apache Beam runner | Your batch + stream processing engine |
| **Dataproc** | Managed Spark/Hadoop | Heavy batch ETL, ML training |
| **Cloud Functions** | Serverless functions | Lightweight event-driven triggers |
| **Cloud Run** | Serverless containers | Microservices, API endpoints |
| **GKE** | Managed Kubernetes | Running Airflow, custom pipeline infra |

### Messaging & Integration

| Service | What It Does | vs Kafka |
|---|---|---|
| **Pub/Sub** | Managed messaging service | GCP-native Kafka alternative, serverless |
| **Pub/Sub Lite** | Zonal, cost-optimized messaging | When you need Kafka-like but cheaper |

### Orchestration & Monitoring

| Service | What It Does |
|---|---|
| **Cloud Composer** | Managed Apache Airflow |
| **Cloud Monitoring** | Metrics, alerting |
| **Cloud Logging** | Centralized logs |
| **Data Catalog** | Metadata management & discovery |
| **Dataplex** | Data governance & quality |

## 2.2 GCP Data Pipeline Architecture (Typical)

```
                         ┌──────────────────────────────────┐
                         │         DATA SOURCES             │
                         │  APIs, DBs, Files, IoT, Events   │
                         └──────────┬───────────────────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    ▼               ▼               ▼
              ┌──────────┐   ┌──────────┐    ┌──────────┐
              │  Pub/Sub  │   │  Kafka   │    │   GCS    │
              │ (stream)  │   │ (stream) │    │ (batch)  │
              └─────┬─────┘   └─────┬────┘    └────┬─────┘
                    │               │              │
                    └───────────────┼──────────────┘
                                    ▼
                         ┌─────────────────────┐
                         │   Apache Beam /      │
                         │   Dataflow           │
                         │   (Transform)        │
                         └──────────┬──────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    ▼               ▼               ▼
              ┌──────────┐   ┌──────────┐    ┌──────────┐
              │ BigQuery  │   │ Bigtable │    │   GCS    │
              │ (analyt.) │   │ (serving)│    │ (archive)│
              └──────────┘   └──────────┘    └──────────┘
                                    │
                         ┌──────────▼──────────┐
                         │  Looker / Dashboards │
                         └─────────────────────┘

         Orchestrated by: Cloud Composer (Airflow)
         Infrastructure:  GKE (Kubernetes)
```

## 2.3 GCP IAM for Data Engineering

```
Organization
  └── Folder (e.g., "Data Platform")
       └── Project (e.g., "prod-data-pipeline")
            ├── BigQuery Dataset → roles/bigquery.dataEditor
            ├── GCS Bucket → roles/storage.objectViewer
            ├── Pub/Sub Topic → roles/pubsub.publisher
            └── Service Account → used by Dataflow jobs
```

**Key Principle**: Always use **Service Accounts** for pipelines, never personal credentials. Apply **least privilege** — a Dataflow job writing to BigQuery needs `bigquery.dataEditor`, not `bigquery.admin`.

## 2.4 BigQuery Deep Dive (Most Asked)

### Concepts to Know

| Concept | Explanation |
|---|---|
| **Partitioning** | Split table by date/integer column → query only relevant partitions → cost savings |
| **Clustering** | Sort data within partitions by chosen columns → faster filters |
| **Materialized Views** | Pre-computed query results, auto-refreshed |
| **External Tables** | Query data in GCS/Bigtable without loading |
| **Streaming Insert** | Real-time row-by-row inserts (vs batch load) |
| **Slots** | Units of compute. On-demand vs flat-rate pricing |
| **INFORMATION_SCHEMA** | System tables for metadata, job history, costs |

### Cost Optimization

```python
# Always use these practices:
# 1. Partition tables by ingestion time or event date
CREATE TABLE my_dataset.events
PARTITION BY DATE(event_timestamp)
CLUSTER BY user_id, event_type
AS SELECT * FROM raw_events;

# 2. Use query cost estimation
SELECT total_bytes_processed
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE job_id = 'your-job-id';

# 3. Avoid SELECT * — specify columns
# 4. Use BigQuery BI Engine for sub-second dashboards
```

---

# 3. Python for Data Engineering

## 3.1 Essential Libraries

| Library | Purpose | Example Use |
|---|---|---|
| `apache-beam` | Beam Python SDK | Building Dataflow pipelines |
| `apache-airflow` | Workflow orchestration | Writing DAGs |
| `confluent-kafka` | Kafka producer/consumer | Stream ingestion |
| `pandas` | Data manipulation | Small-medium transforms |
| `google-cloud-bigquery` | BigQuery client | Loading/querying data |
| `google-cloud-storage` | GCS client | File operations |
| `requests` | HTTP client | API ingestion |
| `pydantic` | Data validation | Schema enforcement |
| `pytest` | Testing | Unit/integration tests |
| `logging` | Structured logging | Pipeline observability |

## 3.2 Python Patterns for Pipelines

### Pattern 1: Idempotent Data Loading

```python
from google.cloud import bigquery
from datetime import date

def load_daily_data(ds: str):
    """
    Idempotent load: DELETE then INSERT for a given date.
    This ensures re-runs don't duplicate data.
    """
    client = bigquery.Client()

    # Step 1: Delete existing data for this date
    delete_query = f"""
        DELETE FROM `project.dataset.events`
        WHERE DATE(event_timestamp) = '{ds}'
    """
    client.query(delete_query).result()

    # Step 2: Insert new data
    insert_query = f"""
        INSERT INTO `project.dataset.events`
        SELECT * FROM `project.dataset.raw_events`
        WHERE DATE(event_timestamp) = '{ds}'
    """
    client.query(insert_query).result()
    print(f"✅ Loaded data for {ds}")
```

### Pattern 2: API Ingestion with Retry & Backoff

```python
import requests
from tenacity import retry, stop_after_attempt, wait_exponential
from google.cloud import storage
import json

@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=2, max=10)
)
def fetch_api_data(endpoint: str) -> dict:
    """Fetch data from API with exponential backoff."""
    response = requests.get(endpoint, timeout=30)
    response.raise_for_status()
    return response.json()

def ingest_to_gcs(endpoint: str, bucket: str, blob_path: str):
    """Fetch from API → Store as JSON in GCS."""
    data = fetch_api_data(endpoint)

    client = storage.Client()
    bucket = client.bucket(bucket)
    blob = bucket.blob(blob_path)
    blob.upload_from_string(
        json.dumps(data),
        content_type='application/json'
    )
    print(f"✅ Uploaded {len(data)} records to gs://{bucket}/{blob_path}")
```

### Pattern 3: Data Validation

```python
from pydantic import BaseModel, validator
from typing import Optional
from datetime import datetime

class EventRecord(BaseModel):
    """Schema validation for incoming events."""
    event_id: str
    user_id: str
    event_type: str
    timestamp: datetime
    metadata: Optional[dict] = None

    @validator('event_type')
    def validate_event_type(cls, v):
        allowed = {'click', 'view', 'purchase', 'signup'}
        if v not in allowed:
            raise ValueError(f"Invalid event_type: {v}. Must be one of {allowed}")
        return v

def validate_batch(records: list[dict]) -> tuple[list, list]:
    """Returns (valid_records, invalid_records)."""
    valid, invalid = [], []
    for record in records:
        try:
            validated = EventRecord(**record)
            valid.append(validated.dict())
        except Exception as e:
            invalid.append({"record": record, "error": str(e)})
    return valid, invalid
```

---

# 4. Apache Kafka — Beginner-Friendly Deep Dive

> [!NOTE]
> **If you're new to Kafka**, read this section carefully. Kafka is one of the most important technologies in modern data engineering. Every section builds on the previous one.

## 4.1 What Is Kafka? (The Simple Explanation)

Imagine a **post office** that never loses mail, can handle millions of letters per second, and lets multiple people read the same letter without it disappearing.

**Apache Kafka** is a **distributed event streaming platform**. It does three things:

1. **Publish & Subscribe** — Send and receive streams of records (like a messaging system)
2. **Store** — Durably store streams of records (like a database log)
3. **Process** — Process streams of records in real-time (like a stream processor)

### Why Not Just Use a Database?

| Feature | Traditional DB | Kafka |
|---|---|---|
| Data model | Tables with rows | Append-only log of events |
| Read pattern | Query current state | Replay history from any point |
| Throughput | Thousands/sec | Millions/sec |
| Consumers | One reader at a time | Multiple independent readers |
| Data retention | Until deleted | Time-based or size-based |
| Use case | "What is the current balance?" | "What happened, in order?" |

## 4.2 Core Concepts (Building Blocks)

### 4.2.1 Topics

A **Topic** is a **named category** or feed to which records are published. Think of it as a **TV channel** — producers broadcast to it, consumers tune in.

```
Topic: "user-clicks"
Topic: "order-events"
Topic: "payment-transactions"
```

### 4.2.2 Partitions

Each topic is split into **Partitions** — these are the unit of parallelism. Think of partitions as **lanes on a highway**.

```
Topic: "order-events" (3 partitions)

  Partition 0: [order-1] [order-4] [order-7] [order-10] →
  Partition 1: [order-2] [order-5] [order-8] [order-11] →
  Partition 2: [order-3] [order-6] [order-9] [order-12] →

  ← Older messages              Newer messages →
```

**Key rules**:
- Messages within a partition are **strictly ordered**
- Messages across partitions have **no ordering guarantee**
- A **key** determines which partition a message goes to (same key = same partition = order preserved)

### 4.2.3 Producers

Producers **write** data to topics. They decide:
- Which topic to write to
- Which partition (via a key or round-robin)
- Acknowledgment level (acks)

```python
from confluent_kafka import Producer

# Create a producer
producer = Producer({
    'bootstrap.servers': 'kafka-broker:9092',
    'acks': 'all'  # Wait for all replicas to confirm
})

# Send a message
producer.produce(
    topic='order-events',
    key='user-123',        # Same user → same partition → ordered
    value='{"order_id": "456", "amount": 99.99}',
    callback=delivery_report
)
producer.flush()  # Wait for all messages to be sent

def delivery_report(err, msg):
    if err:
        print(f'❌ Delivery failed: {err}')
    else:
        print(f'✅ Delivered to {msg.topic()} [{msg.partition()}]')
```

### 4.2.4 Consumers

Consumers **read** data from topics. They track their position (offset) in each partition.

```python
from confluent_kafka import Consumer

consumer = Consumer({
    'bootstrap.servers': 'kafka-broker:9092',
    'group.id': 'order-processing-group',
    'auto.offset.reset': 'earliest'  # Start from beginning if no offset saved
})

consumer.subscribe(['order-events'])

while True:
    msg = consumer.poll(timeout=1.0)  # Wait up to 1 sec for a message
    if msg is None:
        continue
    if msg.error():
        print(f"Error: {msg.error()}")
        continue

    print(f"Received: {msg.value().decode('utf-8')}")
    # Process the message...
```

### 4.2.5 Consumer Groups

A **Consumer Group** is a set of consumers that **cooperate** to consume a topic. Kafka **automatically distributes partitions** among group members.

```
Topic: "order-events" (6 partitions)

Consumer Group: "order-processors"
  ├── Consumer A → reads Partitions 0, 1
  ├── Consumer B → reads Partitions 2, 3
  └── Consumer C → reads Partitions 4, 5

Consumer Group: "analytics-team"   ← Independent group, reads ALL partitions
  └── Consumer D → reads Partitions 0, 1, 2, 3, 4, 5
```

**Key insight**: Two different consumer groups can independently read the same topic. The data is NOT deleted after reading (unlike traditional queues).

### 4.2.6 Offsets

An **Offset** is a unique integer ID for each message within a partition. Consumers track "where am I?" using offsets.

```
Partition 0:  [0] [1] [2] [3] [4] [5] [6] [7] [8]
                                   ↑
                         Consumer's current offset = 4
                         (has read 0-3, will read 4 next)
```

**Committing offsets** = saving your progress. If a consumer crashes and restarts, it resumes from the last committed offset.

### 4.2.7 Brokers & Clusters

```
Kafka Cluster
├── Broker 1 (Server 1)
│   ├── topic-A, partition-0 (LEADER)
│   ├── topic-A, partition-1 (FOLLOWER)
│   └── topic-B, partition-0 (FOLLOWER)
├── Broker 2 (Server 2)
│   ├── topic-A, partition-0 (FOLLOWER)
│   ├── topic-A, partition-1 (LEADER)
│   └── topic-B, partition-0 (LEADER)
└── Broker 3 (Server 3)
    ├── topic-A, partition-0 (FOLLOWER)
    ├── topic-A, partition-1 (FOLLOWER)
    └── topic-B, partition-0 (FOLLOWER)

Replication Factor = 3 (each partition has 3 copies)
```

- **Broker** = a single Kafka server
- **Leader** = the broker that handles reads/writes for a partition
- **Follower** = keeps a copy for fault tolerance
- If a leader dies, a follower is **automatically elected** as new leader

## 4.3 Kafka Architecture Diagram

```
 ┌──────────────────────────────────────────────────────────────────┐
 │                        KAFKA CLUSTER                            │
 │                                                                  │
 │  ┌──────────┐    ┌──────────┐    ┌──────────┐                   │
 │  │ Broker 1 │    │ Broker 2 │    │ Broker 3 │                   │
 │  │          │    │          │    │          │                    │
 │  │ P0(L)    │    │ P0(F)    │    │ P0(F)    │  ← Replication    │
 │  │ P1(F)    │    │ P1(L)    │    │ P1(F)    │                   │
 │  │ P2(F)    │    │ P2(F)    │    │ P2(L)    │                   │
 │  └──────────┘    └──────────┘    └──────────┘                   │
 │       ▲               ▲               ▲                         │
 │       └───────────────┼───────────────┘                         │
 │                       │                                          │
 │              ┌────────┴────────┐                                │
 │              │   ZooKeeper /   │  ← Metadata, leader election   │
 │              │   KRaft         │    (KRaft in newer versions)    │
 │              └─────────────────┘                                │
 └──────────────────────────────────────────────────────────────────┘
        ▲                                           │
        │                                           ▼
 ┌──────┴──────┐                           ┌───────────────┐
 │  Producers  │                           │   Consumers   │
 │             │                           │               │
 │ App Server  │                           │ Beam Pipeline │
 │ IoT Device  │                           │ Spark Job     │
 │ Microservice│                           │ Analytics App │
 └─────────────┘                           └───────────────┘
```

## 4.4 Delivery Semantics (Critical for Interviews)

| Semantic | Meaning | How | Trade-off |
|---|---|---|---|
| **At-most-once** | Message may be lost, never duplicated | Commit offset before processing | Fast, but data loss possible |
| **At-least-once** | Message never lost, may be duplicated | Commit offset after processing | Safe, but needs deduplication |
| **Exactly-once** | Message processed exactly once | Idempotent producer + transactional consumer | Slowest, but perfect accuracy |

```python
# Exactly-once producer configuration
producer = Producer({
    'bootstrap.servers': 'kafka-broker:9092',
    'enable.idempotence': True,        # Prevents duplicates
    'acks': 'all',                      # All replicas must confirm
    'max.in.flight.requests.per.connection': 5,
    'transactional.id': 'my-transactional-producer'
})
```

## 4.5 Kafka on GCP — Your Options

| Option | Description | When to Use |
|---|---|---|
| **Confluent Cloud on GCP** | Fully managed Kafka | Production, need real Kafka |
| **GCP Pub/Sub** | GCP-native alternative | Simpler use cases, no Kafka expertise |
| **Self-managed on GKE** | Run Kafka in Kubernetes | Full control, complex but flexible |
| **Managed Kafka (preview)** | Google-managed Kafka | Best of both worlds (newer offering) |

## 4.6 Common Kafka Patterns in Data Engineering

### Pattern 1: Event Sourcing

```
User clicks "Buy" → Producer sends event to Kafka

Topic: "purchase-events"
  Key: user-id
  Value: {
    "event_type": "purchase",
    "user_id": "u123",
    "product_id": "p456",
    "amount": 29.99,
    "timestamp": "2026-05-15T10:30:00Z"
  }

Consumers:
  1. Order Service → creates the order
  2. Payment Service → charges the card
  3. Analytics Pipeline → updates dashboards
  4. Recommendation Engine → updates user profile
```

### Pattern 2: Change Data Capture (CDC)

```
Database (PostgreSQL)
    │
    ▼ (Debezium connector)
Kafka Topic: "db.public.users"
    │
    ├── Consumer 1: Sync to BigQuery (analytics)
    ├── Consumer 2: Update search index (Elasticsearch)
    └── Consumer 3: Invalidate cache (Redis)
```

### Pattern 3: Dead Letter Queue (DLQ)

```python
def process_message(msg):
    try:
        data = json.loads(msg.value())
        # Process the message
        transform_and_load(data)
    except Exception as e:
        # Send failed message to Dead Letter Queue
        producer.produce(
            topic='order-events-dlq',  # DLQ topic
            key=msg.key(),
            value=msg.value(),
            headers=[('error', str(e).encode())]
        )
        print(f"⚠️ Sent to DLQ: {e}")
```

## 4.7 Kafka Interview Questions & Answers

### Q1: How does Kafka ensure message ordering?
**A**: Ordering is guaranteed **within a single partition only**. Messages with the same key always go to the same partition (via hash), so per-key ordering is guaranteed. Across partitions, there is no global order. If you need global ordering, use a single partition (but this limits throughput).

### Q2: What happens when a consumer in a group dies?
**A**: Kafka triggers a **rebalance**. The partitions assigned to the dead consumer are redistributed among the remaining consumers in the group. This happens automatically via the **Group Coordinator** (a designated broker).

### Q3: How is Kafka different from a traditional message queue (RabbitMQ)?
**A**: 
- Kafka **retains messages** after consumption; queues delete them
- Kafka supports **multiple consumer groups** reading independently
- Kafka is designed for **high throughput** (millions/sec)
- Kafka provides **replay** capability; queues don't
- Kafka is a **distributed commit log**; queues are message routers

### Q4: What is the ISR (In-Sync Replicas)?
**A**: ISR is the set of replicas that are fully caught up with the leader. When `acks=all`, the producer waits for ALL replicas in the ISR to confirm. If a follower falls behind, it's removed from ISR. The `min.insync.replicas` setting controls the minimum ISR size for writes to succeed.

### Q5: How would you handle schema evolution in Kafka?
**A**: Use **Schema Registry** (Confluent). It stores Avro/Protobuf/JSON schemas and enforces compatibility rules (backward, forward, full). Producers register schemas, consumers fetch them. This prevents breaking changes from crashing consumers.

```
Producer → Schema Registry → validates schema → Kafka
Consumer → Schema Registry → fetches schema → deserializes
```

### Q6: Kafka vs Pub/Sub — when would you choose each?
**A**:
- **Kafka**: Need ordering guarantees, replay, exactly-once, complex event processing, multi-cloud
- **Pub/Sub**: GCP-native, serverless (no infra management), simpler use cases, automatic scaling

---

*Continue to Part 2 for Apache Beam and Airflow deep dives →*
