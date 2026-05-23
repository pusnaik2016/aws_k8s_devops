# Data Engineer Comprehensive Guide — Part 3
## Kubernetes · Architecture · Interview Scenarios · Study Plan

---

# 7. Kubernetes for Data Engineering

## 7.1 Why Kubernetes for Data Pipelines?

| Without K8s | With K8s |
|---|---|
| Manual server provisioning | Declarative infra |
| "Works on my machine" | Containerized, reproducible |
| Hard to scale workers | Auto-scaling |
| Dependency conflicts | Isolated containers |
| Complex deployment | Rolling updates, rollbacks |

## 7.2 Key Concepts (Quick Reference)

| Concept | What It Is | Data Engineering Example |
|---|---|---|
| **Pod** | Smallest deployable unit (1+ containers) | A single Airflow worker |
| **Deployment** | Manages Pod replicas | 3 replicas of a Kafka consumer |
| **Service** | Network endpoint for Pods | Expose Airflow web UI |
| **ConfigMap** | Configuration as key-value pairs | Pipeline config (batch size, table names) |
| **Secret** | Encrypted config (passwords, keys) | DB credentials, API keys |
| **PersistentVolumeClaim** | Disk storage | Kafka broker data storage |
| **HorizontalPodAutoscaler** | Auto-scale pods based on metrics | Scale consumers with Kafka lag |
| **Namespace** | Logical isolation | `dev` / `staging` / `prod` environments |
| **CronJob** | Scheduled container execution | Nightly data validation script |

## 7.3 GKE (Google Kubernetes Engine)

GKE is the managed Kubernetes service on GCP. For data engineering:

```
GKE Cluster for Data Platform
├── Namespace: airflow
│   ├── Deployment: airflow-webserver (2 replicas)
│   ├── Deployment: airflow-scheduler (1 replica)
│   ├── Deployment: airflow-worker (3-10 replicas, autoscaled)
│   └── StatefulSet: airflow-db (PostgreSQL)
├── Namespace: kafka
│   ├── StatefulSet: kafka-brokers (3 replicas)
│   └── StatefulSet: zookeeper (3 replicas)
├── Namespace: pipeline-jobs
│   └── CronJob: nightly-data-validation
└── Namespace: monitoring
    ├── Deployment: prometheus
    └── Deployment: grafana
```

## 7.4 KubernetesPodOperator (Airflow + K8s)

This is the bridge between Airflow and Kubernetes — run ANY container as an Airflow task.

```python
from airflow.providers.cncf.kubernetes.operators.kubernetes_pod import (
    KubernetesPodOperator,
)

transform_task = KubernetesPodOperator(
    task_id='run_spark_transform',
    name='spark-transform-job',
    namespace='pipeline-jobs',
    image='gcr.io/my-project/spark-pipeline:v2.1',
    cmds=['python', 'transform.py'],
    arguments=['--date={{ ds }}', '--output=gs://bucket/output/'],
    env_vars={
        'GCP_PROJECT': 'my-project',
        'BQ_DATASET': 'analytics',
    },
    secrets=[secret_env],  # K8s Secret mounted as env var
    resources={
        'request_cpu': '2',
        'request_memory': '4Gi',
        'limit_cpu': '4',
        'limit_memory': '8Gi',
    },
    is_delete_operator_pod=True,  # Clean up after completion
    get_logs=True,                 # Stream logs to Airflow
    startup_timeout_seconds=300,
)
```

**Why KubernetesPodOperator?**
- Each task runs in its **own container** — no dependency conflicts
- Tasks can use **different Python versions, libraries, languages**
- Full **resource control** (CPU, memory limits)
- Easy to **test locally** with Docker

## 7.5 Kubernetes Interview Q&A for Data Engineers

**Q: StatefulSet vs Deployment for Kafka?**
A: Kafka brokers need **stable network identities** and **persistent storage** — use StatefulSet. Stateless services (API, web UI) use Deployments.

**Q: How do you handle secrets in data pipelines on K8s?**
A: Use K8s Secrets + GCP Secret Manager. Mount secrets as env vars or volumes. Never hardcode credentials. In GKE, use Workload Identity to bind K8s service accounts to GCP service accounts.

---

# 8. End-to-End Architecture

## 8.1 All 6 Technologies Working Together

```
┌─────────────────────────────────────────────────────────────────────┐
│                    END-TO-END DATA PLATFORM                        │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    INGESTION LAYER                          │   │
│  │                                                             │   │
│  │   Mobile App ──┐                                            │   │
│  │   Web App ─────┼──► Kafka Topics ──► Raw Events             │   │
│  │   IoT Devices ─┘      │                                    │   │
│  │                        │    APIs ──► Python Scripts ──► GCS │   │
│  │                        │    DBs ──► CDC (Debezium) ──► Kafka│   │
│  └────────────────────────┼────────────────────────────────────┘   │
│                           │                                        │
│  ┌────────────────────────▼────────────────────────────────────┐   │
│  │                    PROCESSING LAYER                         │   │
│  │                                                             │   │
│  │   ┌─────────────────────────────────────┐                   │   │
│  │   │   Apache Beam (on Dataflow)         │                   │   │
│  │   │                                     │                   │   │
│  │   │   Stream Pipeline:                  │                   │   │
│  │   │   Kafka → Parse → Enrich → Window   │                   │   │
│  │   │   → Aggregate → Write to BigQuery   │                   │   │
│  │   │                                     │                   │   │
│  │   │   Batch Pipeline:                   │                   │   │
│  │   │   GCS → Read → Clean → Transform   │                   │   │
│  │   │   → Join → Write to BigQuery        │                   │   │
│  │   └─────────────────────────────────────┘                   │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                           │                                        │
│  ┌────────────────────────▼────────────────────────────────────┐   │
│  │                    STORAGE LAYER                            │   │
│  │                                                             │   │
│  │   GCS (Data Lake)    BigQuery (Warehouse)    Bigtable       │   │
│  │   ├── raw/           ├── raw_events          (low-latency   │   │
│  │   ├── processed/     ├── enriched_events      serving)      │   │
│  │   └── archive/       ├── aggregated_metrics                 │   │
│  │                      └── ml_features                        │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                           │                                        │
│  ┌────────────────────────▼────────────────────────────────────┐   │
│  │                    CONSUMPTION LAYER                        │   │
│  │                                                             │   │
│  │   Looker Dashboards   ML Training   Data Science Notebooks  │   │
│  │   Real-time Alerts    API Serving   Ad-hoc SQL Queries      │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  ORCHESTRATION: Apache Airflow (Cloud Composer)             │   │
│  │  INFRASTRUCTURE: Kubernetes (GKE)                           │   │
│  │  LANGUAGE: Python                                           │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

## 8.2 How They Connect — Data Flow Example

**Scenario**: E-commerce platform processing orders in real-time and batch.

```
Step 1 — KAFKA: User places order → Order Service publishes to
         Kafka topic "order-events" (key=user_id)

Step 2 — BEAM (Streaming): Dataflow streaming job reads from Kafka
         → Parses JSON → Validates schema → Enriches with user data
         (side input from BigQuery) → Windows into 5-min intervals
         → Writes aggregated metrics to BigQuery "realtime_orders"

Step 3 — BEAM (Batch): Nightly Dataflow batch job reads raw orders
         from GCS → Joins with product catalog → Computes daily
         revenue, top products → Writes to BigQuery "daily_summary"

Step 4 — AIRFLOW: Cloud Composer DAG orchestrates the batch pipeline:
         2:00 AM → Sensor: wait for GCS file
         2:05 AM → Task: launch Dataflow batch job
         2:30 AM → Task: data quality checks on BigQuery
         2:35 AM → Task: update ML feature store
         2:40 AM → Task: refresh Looker dashboard cache
         2:45 AM → Task: send Slack summary notification

Step 5 — KUBERNETES: All of the above runs on GKE:
         - Airflow (Cloud Composer) scheduler + workers on GKE
         - Kafka brokers on GKE (StatefulSet)
         - Custom Python tasks via KubernetesPodOperator
         - Dataflow workers are auto-managed VMs (not on GKE)

Step 6 — PYTHON: Every component above is written in Python:
         - Beam pipelines (apache-beam SDK)
         - Airflow DAGs
         - Kafka producers/consumers (confluent-kafka)
         - Data validation (pydantic)
         - API integrations (requests)
```

---

# 9. Scenario-Based Interview Questions

## Scenario 1: Design a Real-Time Fraud Detection Pipeline

**Question**: "Design a system that detects fraudulent transactions in real-time."

**Answer Structure**:

```
1. INGESTION (Kafka):
   - Payment service produces to Kafka topic "transactions"
   - Key = account_id (ensures same account → same partition → ordering)
   - Schema Registry enforces Avro schema

2. PROCESSING (Apache Beam on Dataflow):
   - Read from Kafka topic
   - Enrich: join with account profile (side input from BigQuery)
   - Feature extraction: compute per-user aggregates in sliding windows
     (e.g., "transactions in last 1 hour", "avg amount last 24 hours")
   - ML scoring: call fraud detection model (deployed on Vertex AI)
   - Route: fraud_score > 0.8 → "high-risk" topic
           fraud_score > 0.5 → "review" topic
           else → "approved" topic

3. ACTION:
   - High-risk consumer: block transaction, alert fraud team
   - Review consumer: queue for manual review
   - All events: write to BigQuery for analytics + model retraining

4. ORCHESTRATION (Airflow):
   - Daily DAG: retrain fraud model on new data
   - Hourly DAG: compute fraud metrics dashboard
   - Monitoring DAG: check Dataflow job health, alert on lag

5. INFRASTRUCTURE (GKE):
   - Kafka on GKE (3 brokers, replication factor 3)
   - Fraud model serving on GKE (auto-scaled)
   - Airflow via Cloud Composer (managed GKE)
```

## Scenario 2: Handle a Schema Change in Production

**Question**: "A source API changes its JSON schema. Your streaming pipeline breaks at 3 AM. How do you handle this?"

**Answer**:
```
IMMEDIATE (Incident Response):
1. Check Airflow/Dataflow alerts → identify the failing job
2. Check Dataflow logs → find the parsing error
3. Determine scope: how many records affected?

SHORT-TERM FIX:
1. If backward-compatible change: update the Beam DoFn parser
   to handle both old and new schema
2. Deploy fix: update Dataflow job (drain existing, launch new)
3. Handle backlog: Kafka retains data (retention=7d), so
   the new job will catch up automatically

LONG-TERM FIX:
1. Schema Registry: enforce schema contracts with source teams
2. Schema evolution: use Avro with backward compatibility mode
3. Dead Letter Queue: route unparseable messages to DLQ for
   manual inspection instead of crashing the pipeline
4. Monitoring: add schema validation checks, alert on new fields
```

## Scenario 3: Optimize a Slow BigQuery Pipeline

**Question**: "Your daily pipeline takes 4 hours to process 500GB. How do you optimize?"

**Answer**:
```
INVESTIGATE:
1. Check INFORMATION_SCHEMA.JOBS for slot usage and bytes processed
2. Identify the slowest queries

OPTIMIZE QUERIES:
- Partition tables by date → eliminate full table scans
- Cluster by frequently filtered columns
- Replace SELECT * with specific columns
- Use approximate functions (APPROX_COUNT_DISTINCT vs COUNT(DISTINCT))
- Materialize intermediate results to avoid recomputation

OPTIMIZE PIPELINE:
- Parallelize independent tasks in Airflow (use task groups)
- Use Dataflow instead of sequential BigQuery SQL
- Pre-aggregate in Beam before writing to BigQuery
- Use BigQuery Storage Write API (faster than streaming insert)

OPTIMIZE INFRASTRUCTURE:
- Consider flat-rate slots for predictable workloads
- Use BI Engine for dashboard queries
- Archive old data to GCS (external tables if needed)
```

---

# 10. Four-Week Study Plan

> [!TIP]
> Since you're new to Kafka, Beam, and Airflow — follow this structured plan.

## Week 1: Foundations

| Day | Focus | Activity |
|---|---|---|
| 1-2 | **Kafka basics** | Read this guide's Section 4. Set up local Kafka with Docker. Write producer/consumer in Python |
| 3-4 | **Beam basics** | Read Section 5. Install `apache-beam`. Run word-count example locally with `DirectRunner` |
| 5-6 | **Airflow basics** | Read Section 6. Install Airflow locally. Create a simple DAG with PythonOperator |
| 7 | **Review** | Revisit concepts, re-read diagrams |

## Week 2: Intermediate + GCP

| Day | Focus | Activity |
|---|---|---|
| 1-2 | **Kafka deep dive** | Consumer groups, rebalancing, exactly-once. Try multi-consumer setup |
| 3-4 | **Beam on Dataflow** | Run a Beam pipeline on GCP Dataflow. Use BigQuery I/O |
| 5-6 | **Airflow DAG patterns** | Branching, XCom, dynamic tasks, Sensors. Use BigQuery operators |
| 7 | **GCP services** | Explore BigQuery, GCS, Pub/Sub in the GCP Console |

## Week 3: Advanced + Integration

| Day | Focus | Activity |
|---|---|---|
| 1-2 | **Kafka + Beam** | Build a streaming pipeline: Kafka → Beam → BigQuery |
| 3-4 | **Airflow + Beam** | Orchestrate a Beam batch job from an Airflow DAG |
| 5-6 | **Kubernetes** | Deploy a simple app on GKE. Use KubernetesPodOperator |
| 7 | **End-to-end** | Draw the full architecture diagram from memory |

## Week 4: Interview Prep

| Day | Focus | Activity |
|---|---|---|
| 1-2 | **Design scenarios** | Practice the 3 scenarios in Section 9 |
| 3-4 | **Q&A review** | Go through all Q&A sections. Practice explaining out loud |
| 5-6 | **Mock interviews** | Have someone ask you to design a data pipeline. Whiteboard it |
| 7 | **Gaps** | Revisit anything you're still unsure about |

---

# 11. Quick Cheat Sheet — All Technologies

```
┌─────────────┬──────────────────────────────────────────────────────┐
│ Technology  │ One-Line Summary                                     │
├─────────────┼──────────────────────────────────────────────────────┤
│ GCP         │ The cloud platform — provides all managed services   │
│ Python      │ The language — writes ALL pipeline code               │
│ Kafka       │ The MESSENGER — moves events between systems         │
│ Apache Beam │ The PROCESSOR — transforms data (batch + stream)     │
│ Airflow     │ The SCHEDULER — orchestrates when things run         │
│ Kubernetes  │ The INFRASTRUCTURE — runs containers at scale        │
├─────────────┼──────────────────────────────────────────────────────┤
│ Together    │ Kafka ingests → Beam processes → BigQuery stores →   │
│             │ Airflow orchestrates → K8s runs everything → Python  │
│             │ writes everything                                    │
└─────────────┴──────────────────────────────────────────────────────┘
```

---

*End of Data Engineer Comprehensive Guide (3 Parts)*
