# EXL Services — AI Cloud Architect: JD-Aligned Supplemental Questions

> **Purpose:** Addresses gaps identified between the original Q&A file and the detailed JD.  
> **Key JD themes missing:** Stage-Gated AI Environments, AI SDLC, AI Governance Framework,  
> Databricks, LLMOps, AI Onboarding Blueprints, Policy-as-Code, LangChain/MLflow/Kubeflow,  
> Vector Databases, ECS patterns, EventBridge, Managed Grafana, Unity Catalog  
> **Read this AFTER the main file:** `EXL_AI_Cloud_Architect_L1_Interview_Preparation.md`

---

## Table of Contents

1. [Stage-Gated AI Platform Architecture](#1-stage-gated-ai-platform-architecture)
2. [AI SDLC & Environment Promotion](#2-ai-sdlc--environment-promotion)
3. [AI Governance Framework](#3-ai-governance-framework)
4. [LLMOps — LLM Operationalization](#4-llmops--llm-operationalization)
5. [Databricks & Modern Data Platforms](#5-databricks--modern-data-platforms)
6. [LangChain, MLflow & AI Orchestration](#6-langchain-mlflow--ai-orchestration)
7. [Vector Databases & Embedding Pipelines](#7-vector-databases--embedding-pipelines)
8. [AI Onboarding Blueprints & Reference Architectures](#8-ai-onboarding-blueprints--reference-architectures)
9. [Policy-as-Code & Governance Automation](#9-policy-as-code--governance-automation)
10. [ECS, EventBridge & Serverless AI Patterns](#10-ecs-eventbridge--serverless-ai-patterns)
11. [AI Observability & Operational Governance](#11-ai-observability--operational-governance)
12. [AWS Control Tower Deep Dive](#12-aws-control-tower-deep-dive)
13. [AI Cost Governance & Tagging](#13-ai-cost-governance--tagging)
14. [Responsible AI & Model Risk Management](#14-responsible-ai--model-risk-management)
15. [Updated Behavioral Answers (JD-Aligned)](#15-updated-behavioral-answers-jd-aligned)

---

## 1. Stage-Gated AI Platform Architecture

### Q41: The JD specifically mentions Sandbox, PoC/Dev, Pilot, and Production environments. How would you architect a stage-gated AI platform on AWS?

**Answer:**  
This is the core architectural pattern the role demands — a progressive environment lifecycle for AI workloads with increasing governance at each stage:

```
STAGE-GATED AI PLATFORM ARCHITECTURE:

┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  SANDBOX    │ →  │  POC / DEV  │ →  │   PILOT     │ →  │ PRODUCTION  │
│             │    │             │    │             │    │             │
│ Experiment  │    │ Build &     │    │ Validate &  │    │ Operate &   │
│ freely      │    │ Iterate     │    │ Harden      │    │ Scale       │
├─────────────┤    ├─────────────┤    ├─────────────┤    ├─────────────┤
│ AWS Account │    │ AWS Account │    │ AWS Account │    │ AWS Account │
│ (Sandbox OU)│    │ (Dev OU)    │    │ (Pilot OU)  │    │ (Prod OU)   │
├─────────────┤    ├─────────────┤    ├─────────────┤    ├─────────────┤
│ Budget: $500│    │ Budget: $5K │    │ Budget: $20K│    │ Budget: Flex│
│ /month/user │    │ /month/proj │    │ /month/proj │    │ (approved)  │
├─────────────┤    ├─────────────┤    ├─────────────┤    ├─────────────┤
│ Data:       │    │ Data:       │    │ Data:       │    │ Data:       │
│ Synthetic / │    │ Anonymized  │    │ Production  │    │ Production  │
│ Public only │    │ sample      │    │ subset      │    │ Full        │
├─────────────┤    ├─────────────┤    ├─────────────┤    ├─────────────┤
│ Governance: │    │ Governance: │    │ Governance: │    │ Governance: │
│ Minimal     │    │ Basic IAM   │    │ Full audit  │    │ Full compl. │
│ (SCP guard  │    │ + logging   │    │ + security  │    │ + SLA       │
│  rails only)│    │ + tagging   │    │ review gate │    │ + DR        │
├─────────────┤    ├─────────────┤    ├─────────────┤    ├─────────────┤
│ Services:   │    │ Services:   │    │ Services:   │    │ Services:   │
│ SageMaker   │    │ SageMaker   │    │ All of Dev  │    │ All of Pilot│
│ Studio,     │    │ (full),     │    │ + Bedrock   │    │ + HA config │
│ Notebooks,  │    │ Bedrock,    │    │ Guardrails, │    │ + Auto-scale│
│ Bedrock     │    │ S3, ECR,    │    │ Model Mon., │    │ + Backup    │
│ (base only) │    │ Lambda, ECS │    │ VPC endpts  │    │ + WAF       │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘

PROMOTION GATES:
  Sandbox → PoC:    Self-service (team lead approval)
  PoC → Pilot:      Architecture review + Security review
  Pilot → Prod:     Full CAB (Change Advisory Board) + compliance sign-off
```

**AWS Implementation:**

| Environment | AWS Account Strategy | Key Controls |
|-------------|---------------------|--------------|
| **Sandbox** | Separate AWS account per team in Sandbox OU | SCPs: deny production services, budget alerts at $500, auto-terminate after 30 days |
| **PoC/Dev** | Shared dev account per project in Dev OU | IAM Identity Center roles, CloudTrail enabled, cost allocation tags mandatory |
| **Pilot** | Dedicated account in Pilot OU (mirrors prod) | VPC endpoints, KMS encryption, Model Monitor, security scanning, GuardDuty |
| **Production** | Dedicated account in Prod OU | Full compliance controls, HA, auto-scaling, DR, WAF, Shield, 24/7 monitoring |

---

### Q42: How do you handle data access differently across these 4 environments?

**Answer:**  
Data governance is the primary differentiator between environments:

```
DATA ACCESS STRATEGY BY ENVIRONMENT:

┌───────────┬──────────────────────┬────────────────────┬───────────────────┐
│ Env       │ Data Type            │ Access Method      │ Controls          │
├───────────┼──────────────────────┼────────────────────┼───────────────────┤
│ Sandbox   │ Synthetic data only  │ Pre-loaded in S3   │ No prod access    │
│           │ Public datasets      │ bucket (read-only) │ SCPs block cross- │
│           │ Faker-generated PII  │                    │ account access    │
├───────────┼──────────────────────┼────────────────────┼───────────────────┤
│ PoC/Dev   │ Anonymized sample    │ S3 cross-account   │ Lake Formation    │
│           │ (10% of prod, masked)│ role assumption    │ column-level      │
│           │ PII fields hashed    │ via assume-role    │ access policies   │
├───────────┼──────────────────────┼────────────────────┼───────────────────┤
│ Pilot     │ Production subset    │ Same as prod but   │ Full audit logging│
│           │ (time-bounded)       │ read-only access   │ Macie PII scan    │
│           │ Full PII (encrypted) │ KMS cross-account  │ Data retention    │
├───────────┼──────────────────────┼────────────────────┼───────────────────┤
│ Production│ Full production data │ Direct access      │ Full compliance   │
│           │ Real-time streams    │ VPC endpoints      │ Encryption, audit │
│           │                      │ IAM least-priv     │ Backup, DR        │
└───────────┴──────────────────────┴────────────────────┴───────────────────┘

Data Masking Pipeline (for Dev/PoC):
  Prod S3 → Glue ETL (mask/hash PII columns) → Dev S3 bucket
  Uses: SHA-256 hashing for identifiers, Faker for names/addresses
  Schedule: Weekly refresh, automated via Step Functions
```

---

## 2. AI SDLC & Environment Promotion

### Q43: Define an enterprise AI SDLC with approval gates and deployment standards

**Answer:**  
The AI SDLC I define has 6 stages with explicit approval gates:

```
AI SOFTWARE DEVELOPMENT LIFECYCLE:

Stage 1: IDEATION & USE CASE ASSESSMENT
├── Business case documentation
├── Data availability assessment
├── Feasibility study (can AI solve this? what's the baseline?)
├── Risk classification (high/medium/low based on regulatory impact)
└── GATE: Business sponsor + AI CoE approval
         ↓
Stage 2: DATA PREPARATION & EXPLORATION (Sandbox/PoC)
├── Data discovery in Glue Catalog
├── Exploratory analysis in SageMaker Studio notebooks
├── Feature engineering prototyping
├── Data quality assessment
└── GATE: Data steward approval (data is appropriate for use case)
         ↓
Stage 3: MODEL DEVELOPMENT (PoC/Dev)
├── Model training (SageMaker Training/JumpStart)
├── Experiment tracking (SageMaker Experiments)
├── Hyperparameter tuning
├── Bias & fairness evaluation (SageMaker Clarify)
├── Model card creation
└── GATE: Data Science lead review + Model Risk Management review
         ↓
Stage 4: VALIDATION & HARDENING (Pilot)
├── Integration testing with downstream systems
├── Performance/load testing (latency, throughput)
├── Security review (IAM, encryption, network)
├── Model Monitor baseline creation
├── Deployment runbook creation
├── DR testing
└── GATE: Architecture review board + Security review + Compliance sign-off
         ↓
Stage 5: PRODUCTION DEPLOYMENT (Production)
├── Blue/green or canary deployment
├── A/B testing (shadow mode first)
├── Full monitoring enabled (Model Monitor + CloudWatch)
├── Operational handover to SRE/Platform team
└── GATE: CAB (Change Advisory Board) approval
         ↓
Stage 6: OPERATE & ITERATE
├── Continuous monitoring (drift, quality, bias)
├── Automated retraining triggered by drift
├── Model version management (Model Registry)
├── Quarterly model revalidation (regulatory requirement for BFSI)
└── GATE: Annual model review (regulatory compliance)
```

**Tooling for each gate:**

| Gate | Enforced By | Artifacts Required |
|------|------------|-------------------|
| Business approval | Jira/ServiceNow workflow | Business case doc, ROI estimate |
| Data approval | AWS Lake Formation + custom approval Lambda | Data lineage report, PII assessment |
| Model approval | SageMaker Model Registry (`PendingManualApproval`) | Model card, Clarify bias report, metrics |
| Architecture/Security | Custom Step Functions workflow | Architecture diagram, threat model, pen test |
| CAB approval | ServiceNow Change Management | Deployment plan, rollback plan, runbook |

---

### Q44: How do you implement environment promotion workflows for AI models?

**Answer:**

```
MODEL PROMOTION WORKFLOW:

Dev (SageMaker Model Registry)
  │
  │  Model registered as "PendingManualApproval"
  │  Artifacts: model.tar.gz, metrics.json, bias_report.json, model_card.md
  │
  ▼
Pilot (Approved → deployed to pilot endpoint)
  │
  │  Automated:
  │  ├── Deploy to pilot SageMaker endpoint
  │  ├── Run integration tests (pytest against endpoint)
  │  ├── Run load tests (Locust, 1000 RPS for 30 min)
  │  ├── Enable Model Monitor (create baseline)
  │  ├── Run 7-day shadow traffic comparison
  │  │
  │  Manual:
  │  ├── Security team reviews VPC/IAM config
  │  ├── Compliance team reviews model card + bias report
  │  └── Business team validates sample predictions
  │
  ▼
Production (CAB approved → blue/green deployment)
  │
  │  ├── Blue/green deployment (zero downtime)
  │  ├── Canary: 10% traffic → 50% → 100% (over 48 hours)
  │  ├── Full CloudWatch alarms enabled
  │  ├── Model Monitor activated (hourly checks)
  │  └── Operational runbook handed to SRE

CI/CD IMPLEMENTATION:
  GitHub Actions workflow:
    on:
      model_registry_event:
        status: "Approved"
    jobs:
      deploy-pilot:
        # Terraform apply for pilot SageMaker endpoint
      integration-test:
        # pytest against pilot endpoint
      deploy-prod:
        needs: [integration-test]
        environment: production  # requires GitHub Environment approval
        # Terraform apply for prod SageMaker endpoint
```

---

## 3. AI Governance Framework

### Q45: How would you establish an enterprise AI governance framework on AWS?

**Answer:**  
AI governance spans identity, data, model, and operational governance:

```
ENTERPRISE AI GOVERNANCE FRAMEWORK:

┌──────────────────────────────────────────────────────────────────────┐
│                    AI GOVERNANCE PILLARS                              │
│                                                                       │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌─────────────┐ │
│  │   IDENTITY   │ │    DATA      │ │    MODEL     │ │ OPERATIONAL │ │
│  │  GOVERNANCE  │ │  GOVERNANCE  │ │  GOVERNANCE  │ │ GOVERNANCE  │ │
│  ├──────────────┤ ├──────────────┤ ├──────────────┤ ├─────────────┤ │
│  │ IAM Identity │ │ Data class-  │ │ Model cards  │ │ Monitoring  │ │
│  │ Center (SSO) │ │ ification   │ │ & registry   │ │ & alerting  │ │
│  │              │ │ (Macie)      │ │              │ │             │ │
│  │ SageMaker    │ │ Encryption   │ │ Bias/fairness│ │ Drift       │ │
│  │ execution    │ │ standards    │ │ testing      │ │ detection   │ │
│  │ roles        │ │ (KMS CMK)    │ │ (Clarify)    │ │ (Monitor)   │ │
│  │              │ │              │ │              │ │             │ │
│  │ Least-priv   │ │ Lake Form-   │ │ Explainabil- │ │ Cost        │ │
│  │ policies     │ │ ation access │ │ ity (SHAP)   │ │ tracking    │ │
│  │              │ │ controls     │ │              │ │             │ │
│  │ MFA enforce  │ │ Retention    │ │ Approval     │ │ Incident    │ │
│  │              │ │ policies     │ │ workflows    │ │ response    │ │
│  │ Session      │ │              │ │              │ │             │ │
│  │ policies     │ │ PII scanning │ │ Version      │ │ Audit logs  │ │
│  │              │ │ & masking    │ │ control      │ │ (CloudTrail)│ │
│  └──────────────┘ └──────────────┘ └──────────────┘ └─────────────┘ │
│                                                                       │
│  ENFORCEMENT LAYER:                                                   │
│  ├── SCPs (Service Control Policies) — account-level guardrails      │
│  ├── IAM Permission Boundaries — role-level limits                   │
│  ├── S3 Bucket Policies — data access controls                       │
│  ├── VPC Endpoint Policies — network-level restrictions              │
│  ├── Bedrock Guardrails — LLM safety controls                       │
│  ├── AWS Config Rules — continuous compliance checking               │
│  └── OPA/Sentinel (Policy-as-Code) — Terraform guardrails           │
└──────────────────────────────────────────────────────────────────────┘
```

**Data Classification Controls:**

| Classification | Label | Storage | Encryption | Access | AI Usage |
|---------------|-------|---------|------------|--------|----------|
| **Restricted** | PII, financial data | Dedicated S3 buckets | KMS CMK | Named individuals only | Only in Pilot/Prod with approval |
| **Confidential** | Internal business data | Standard S3 | KMS CMK | Team-level | PoC/Dev with anonymization |
| **Internal** | Non-sensitive business | Standard S3 | SSE-S3 | Department-level | Any environment |
| **Public** | Open datasets | Standard S3 | SSE-S3 | All users | Sandbox and above |

**Secrets Management:**

```
AWS Secrets Manager (primary)
├── Database credentials (auto-rotation: 30 days)
├── API keys for external services
├── Model endpoint API tokens
├── Bedrock custom model ARNs

Integration:
├── ECS/EKS: Secrets injected as env vars via Secrets Manager CSI driver
├── Lambda: Secrets cached via AWS Parameters and Secrets Extension
├── SageMaker: Secrets retrieved in training scripts via boto3
├── Terraform: aws_secretsmanager_secret data source (never in state)
```

---

## 4. LLMOps — LLM Operationalization

### Q46: How does LLMOps differ from traditional MLOps, and how would you implement it?

**Answer:**  
LLMOps extends MLOps with patterns specific to large language models:

| Aspect | Traditional MLOps | LLMOps |
|--------|------------------|--------|
| **Model training** | Train from scratch, full fine-tuning | Prompt engineering → few-shot → fine-tuning (LoRA) → pre-training (rare) |
| **Evaluation** | Accuracy, F1, AUC-ROC (quantitative) | Human eval + LLM-as-judge + quantitative (ROUGE, BLEU, BERTScore) |
| **Versioning** | Model artifacts (model.tar.gz) | Model + prompts + guardrail configs + RAG knowledge base |
| **Monitoring** | Data drift, model quality | + Token usage, latency, cost per query, hallucination rate, guardrail hit rate |
| **Cost model** | Instance hours | Token-based (input/output pricing) — much harder to predict |
| **Testing** | Unit tests + integration tests | + Adversarial testing, prompt injection, jailbreak attempts |
| **Governance** | Model registry | + Prompt registry + guardrail versioning + knowledge base versioning |

**My LLMOps Architecture on AWS:**

```
LLMOPS PIPELINE:

Prompt Development:
  Git (prompt YAML) → CI/CD → Prompt Registry (DynamoDB)
    ├── Version control for system/user prompts
    ├── A/B test configuration
    └── Guardrail association

Knowledge Base Updates:
  S3 (docs) → Lambda trigger → Bedrock KB re-sync
    ├── Automated chunking + embedding refresh
    ├── Version tracking (S3 versioning)
    └── Quality checks (retrieval accuracy test suite)

Model Updates:
  SageMaker fine-tuning → Model Registry → Bedrock custom model import
    ├── Evaluation pipeline (human + automated)
    ├── Bias/safety testing (red teaming)
    └── Approval workflow

Monitoring Dashboard (Managed Grafana):
  ├── Token usage per model (cost tracking)
  ├── Latency percentiles (p50, p95, p99)
  ├── Guardrail intervention rate
  ├── Hallucination detection rate (grounding score)
  ├── User satisfaction score (thumbs up/down)
  └── Error rate and retry rate
```

---

### Q47: How do you evaluate LLM quality in production?

**Answer:**

```
LLM EVALUATION FRAMEWORK:

1. OFFLINE EVALUATION (before deployment):
   ├── Automated metrics:
   │   ├── ROUGE-L (summarization quality)
   │   ├── BERTScore (semantic similarity)
   │   ├── Exact Match / F1 (extraction tasks)
   │   └── Perplexity (language model quality)
   ├── LLM-as-Judge:
   │   ├── Use Claude to evaluate another model's outputs
   │   ├── Rubric: Accuracy (1-5), Relevance (1-5), Helpfulness (1-5)
   │   └── Automated scoring of 500+ test cases
   └── Human evaluation:
       ├── Domain experts rate 200 samples
       └── Inter-annotator agreement check

2. ONLINE EVALUATION (in production):
   ├── User feedback: thumbs up/down → DynamoDB → analytics
   ├── Groundedness score: % of responses citing source docs
   ├── Guardrail hit rate: how often guardrails intervene
   ├── Fallback rate: how often LLM returns "I don't know"
   └── A/B testing: compare prompt variants on live traffic
```

---

## 5. Databricks & Modern Data Platforms

### Q48: The JD mentions Databricks. How does it fit into the AI platform?

**Answer:**  
Databricks is a key modern data platform — especially for clients who use it as their primary data/ML environment:

```
DATABRICKS ON AWS — ARCHITECTURE:

┌──────────────────────────────────────────────────────────────────────┐
│  DATABRICKS WORKSPACE (deployed in customer VPC)                     │
│                                                                       │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐                 │
│  │ Data         │ │ ML/AI        │ │ SQL          │                 │
│  │ Engineering  │ │ (ML Runtime) │ │ Analytics    │                 │
│  ├──────────────┤ ├──────────────┤ ├──────────────┤                 │
│  │ Delta Lake   │ │ MLflow       │ │ SQL Warehouse│                 │
│  │ (Bronze →    │ │ (Experiment  │ │ (BI/Reports) │                 │
│  │  Silver →    │ │  Tracking,   │ │              │                 │
│  │  Gold)       │ │  Model Reg.) │ │ Dashboards   │                 │
│  │              │ │              │ │              │                 │
│  │ Auto Loader  │ │ Feature      │ │ Unity Catalog│                 │
│  │ (streaming   │ │ Store        │ │ (Governance) │                 │
│  │  ingestion)  │ │              │ │              │                 │
│  └──────────────┘ └──────────────┘ └──────────────┘                 │
│                                                                       │
│  UNDERLYING AWS:                                                      │
│  ├── S3 (Delta Lake storage)                                         │
│  ├── EC2 (compute clusters — spot instances)                         │
│  ├── IAM (instance profiles for S3/service access)                   │
│  └── VPC (customer-managed, PrivateLink to Databricks control plane) │
└──────────────────────────────────────────────────────────────────────┘
```

**Databricks vs SageMaker — When to Use What:**

| Capability | Databricks | SageMaker | My Recommendation |
|-----------|-----------|-----------|-------------------|
| **Data Engineering** | ✅ Delta Lake, Spark, Auto Loader | ❌ Not its strength | Databricks |
| **Experiment Tracking** | ✅ MLflow (built-in) | ✅ SageMaker Experiments | Either (MLflow more portable) |
| **Model Training** | ✅ ML Runtime + GPU clusters | ✅ Managed training + Spot | SageMaker (better managed infra) |
| **Model Serving** | ⚠️ Model Serving (newer) | ✅ Endpoints (mature, auto-scale) | SageMaker |
| **LLM/GenAI** | ✅ Foundation Model APIs + fine-tuning | ✅ Bedrock + JumpStart | Both (Bedrock for inference, Databricks for data prep) |
| **Data Governance** | ✅ Unity Catalog | ⚠️ Lake Formation (less integrated) | Databricks (Unity Catalog is superior) |
| **Feature Store** | ✅ Feature Store | ✅ Feature Store (Online+Offline) | SageMaker (online store for real-time) |

**My approach for EXL clients:**

- **Databricks** for data engineering (Delta Lake medallion architecture) + experiment tracking (MLflow) + data governance (Unity Catalog)
- **SageMaker** for model training (managed infra, Spot, HPO) + production serving (endpoints) + monitoring (Model Monitor)
- **Bedrock** for GenAI inference (Bedrock Guardrails, managed RAG)
- This is a **complementary** stack, not either/or

---

### Q49: What is Unity Catalog and how does it enable AI governance?

**Answer:**  
Unity Catalog is Databricks' unified governance layer for data and AI assets:

| Capability | Description | AI Governance Value |
|-----------|-------------|-------------------|
| **Data Discovery** | Catalog all tables, volumes, models across workspaces | Know what data exists before building models |
| **Fine-grained Access** | Column-level, row-level security | Restrict PII columns to authorized roles |
| **Lineage** | Track data → feature → model → endpoint | Full audit trail for regulatory compliance |
| **Model Registry** | Version models with metadata, tags, aliases | Govern model lifecycle alongside data |
| **Lakehouse Monitoring** | Data quality, drift monitoring | Continuous data health for ML pipelines |
| **Delta Sharing** | Securely share data across organizations | Share anonymized datasets with EXL analytics teams |

**Comparison with AWS Lake Formation:**

| Feature | Unity Catalog | AWS Lake Formation |
|---------|--------------|-------------------|
| Data cataloging | ✅ Automatic | ✅ Via Glue Catalog |
| Column-level security | ✅ Native | ✅ Native |
| Row-level security | ✅ Native | ✅ Via row filters |
| ML model governance | ✅ Built-in | ❌ Need SageMaker Model Registry separately |
| Cross-platform lineage | ✅ (Spark, SQL, ML) | ⚠️ Limited to Glue jobs |

---

## 6. LangChain, MLflow & AI Orchestration

### Q50: How do you use LangChain for enterprise GenAI applications?

**Answer:**  
LangChain is my primary orchestration framework for building RAG and agent-based GenAI applications:

```python
# Production LangChain RAG with Bedrock (my standard pattern)
from langchain_aws import ChatBedrock, BedrockEmbeddings
from langchain_community.vectorstores import OpenSearchVectorSearch
from langchain.chains import RetrievalQA
from langchain.prompts import PromptTemplate

# Model — Claude 3.5 Sonnet via Bedrock
llm = ChatBedrock(
    model_id="anthropic.claude-3-5-sonnet-20241022-v2:0",
    region_name="us-east-1",
    model_kwargs={"temperature": 0.1, "max_tokens": 4096},
)

# Embeddings — Titan V2 via Bedrock
embeddings = BedrockEmbeddings(
    model_id="amazon.titan-embed-text-v2:0",
    region_name="us-east-1",
)

# Vector Store — OpenSearch Serverless
vectorstore = OpenSearchVectorSearch(
    opensearch_url="https://collection-id.us-east-1.aoss.amazonaws.com",
    index_name="policy-documents",
    embedding_function=embeddings,
)

# RAG Chain with custom prompt
prompt_template = PromptTemplate(
    template="""You are an insurance policy expert.
    Use ONLY the following context to answer. If unsure, say "I don't know."
    
    Context: {context}
    Question: {question}
    
    Answer (cite document sources):""",
    input_variables=["context", "question"],
)

qa_chain = RetrievalQA.from_chain_type(
    llm=llm,
    retriever=vectorstore.as_retriever(search_kwargs={"k": 5}),
    chain_type_kwargs={"prompt": prompt_template},
    return_source_documents=True,
)
```

**LangChain components I use in production:**

| Component | Purpose | AWS Integration |
|-----------|---------|----------------|
| **ChatBedrock** | LLM inference | Amazon Bedrock |
| **BedrockEmbeddings** | Text → vector | Bedrock Titan Embeddings |
| **OpenSearchVectorSearch** | Vector store | OpenSearch Serverless |
| **ConversationBufferMemory** | Chat history | DynamoDB |
| **LangSmith** | Tracing, debugging, evaluation | External (or CloudWatch alternative) |
| **LCEL (LangChain Expression Language)** | Chain composition | N/A (application layer) |

---

### Q51: How do you use MLflow for ML experiment tracking?

**Answer:**  
MLflow is the industry standard for experiment tracking — I use it both standalone and within Databricks:

```
MLFLOW ON AWS (STANDALONE DEPLOYMENT):

Architecture:
  ECS Fargate (MLflow server) + RDS PostgreSQL (backend) + S3 (artifact store)

Usage in AI SDLC:
  ┌─────────────────────────────────────────────────────┐
  │  Data Scientist (SageMaker Studio / Notebook)       │
  │                                                      │
  │  import mlflow                                       │
  │  mlflow.set_tracking_uri("https://mlflow.internal") │
  │  mlflow.set_experiment("fraud-detection-v3")         │
  │                                                      │
  │  with mlflow.start_run():                            │
  │      mlflow.log_params(hyperparams)                  │
  │      mlflow.log_metrics({"f1": 0.92, "auc": 0.97}) │
  │      mlflow.sklearn.log_model(model, "model")        │
  │      mlflow.log_artifact("bias_report.html")         │
  └─────────────────────────────────────────────────────┘
```

**MLflow vs SageMaker Experiments:**

| Feature | MLflow | SageMaker Experiments |
|---------|--------|----------------------|
| **Vendor lock-in** | Open-source, portable | AWS-specific |
| **UI** | Excellent, feature-rich | Basic |
| **Model Registry** | ✅ Stages (Staging/Prod) | ✅ Approval workflow |
| **Integration** | Universal (Spark, PyTorch, TF, SK) | SageMaker-focused |
| **Databricks native** | ✅ Built-in | ❌ Separate |

**My recommendation for EXL:** Use MLflow when clients have Databricks; use SageMaker Experiments when clients are SageMaker-native. Both integrate into CI/CD.

---

### Q52: How would you use Kubeflow on AWS?

**Answer:**  
Kubeflow on EKS is useful for clients who want Kubernetes-native ML pipelines:

```
KUBEFLOW ON AWS EKS:

EKS Cluster
├── Kubeflow Pipelines (DAG-based ML workflows)
├── Katib (hyperparameter tuning — like SageMaker HPO)
├── KFServing / KServe (model serving — like SageMaker endpoints)
├── Notebooks (JupyterHub — like SageMaker Studio)
└── Training Operators (TFJob, PyTorchJob — distributed training)

When to use Kubeflow over SageMaker:
├── Client has existing EKS investment
├── Multi-cloud portability requirement
├── Custom training frameworks not supported by SageMaker
└── Team has strong Kubernetes expertise

When to prefer SageMaker:
├── Managed infrastructure (less operational overhead)
├── Built-in governance (Model Registry, Model Monitor, Clarify)
├── AWS-native integrations (Feature Store, Bedrock)
└── Cost optimization (Spot training, Savings Plans)
```

---

## 7. Vector Databases & Embedding Pipelines

### Q53: Design a vector database and embedding pipeline architecture for enterprise RAG

**Answer:**

```
ENTERPRISE EMBEDDING PIPELINE:

Document Sources:
  ├── S3 (PDFs, Word, policies)
  ├── Confluence / SharePoint (wikis)
  ├── RDS/DynamoDB (structured data)
  └── Real-time feeds (Kinesis)
          ↓
Ingestion & Chunking:
  ├── Lambda / ECS (document processing)
  ├── Chunking strategy:
  │   ├── Fixed-size: 512 tokens, 50 token overlap
  │   ├── Semantic: Split by paragraph/heading
  │   └── Parent-child: Store full doc + chunks
  ├── Metadata enrichment:
  │   ├── Source document, page number
  │   ├── Department, classification
  │   └── Created date, author
          ↓
Embedding:
  ├── Amazon Titan Embedding V2 (1024 dims, via Bedrock)
  ├── or Cohere Embed v3 (via Bedrock)
  ├── Batch processing: SageMaker Batch Transform
  └── Real-time: Lambda + Bedrock API
          ↓
Vector Store (choose based on scale):
  ├── OpenSearch Serverless (< 10M vectors, managed, AWS-native)
  ├── Amazon Aurora + pgvector (< 1M vectors, existing RDS)
  ├── Pinecone (multi-cloud, managed, best query perf)
  └── Amazon Neptune (graph + vector, knowledge graphs)
          ↓
Retrieval:
  ├── k-NN search (cosine similarity)
  ├── Hybrid search: vector + keyword (BM25) fusion
  ├── Metadata filtering (department, date range)
  └── Re-ranking (Cohere Rerank via Bedrock)
```

**Vector Database Comparison:**

| Database | Max Vectors | Latency | Managed | AWS-Native | Best For |
|----------|-----------|---------|---------|-----------|----------|
| **OpenSearch Serverless** | 10M+ | < 50ms | ✅ | ✅ | Enterprise RAG (my default) |
| **pgvector (Aurora)** | 1M | < 100ms | ✅ | ✅ | Small-scale, existing RDS |
| **Pinecone** | 100M+ | < 20ms | ✅ | ❌ | High-performance, multi-cloud |
| **Amazon MemoryDB** | 10M+ | < 10ms | ✅ | ✅ | Ultra-low latency |

---

## 8. AI Onboarding Blueprints & Reference Architectures

### Q54: How would you create reusable architecture blueprints for AI/GenAI application onboarding?

**Answer:**  
This is a core JD requirement — standardized, repeatable patterns for new AI projects:

```
AI ONBOARDING BLUEPRINT LIBRARY:

Blueprint 1: RAG Chatbot
├── Terraform module: bedrock-rag-chatbot/
│   ├── Bedrock KB + OpenSearch Serverless
│   ├── API Gateway + Lambda backend
│   ├── Bedrock Guardrails (PII, denied topics)
│   ├── DynamoDB (session store)
│   ├── CloudWatch dashboard
│   └── IAM roles (least-privilege)
├── Onboarding time: 2 days (Terraform apply)
└── Customization: Client provides S3 docs + guardrail rules

Blueprint 2: Real-Time ML Inference
├── Terraform module: sagemaker-realtime-inference/
│   ├── SageMaker Endpoint (auto-scaling)
│   ├── Model Monitor (drift detection)
│   ├── API Gateway + Lambda (API layer)
│   ├── Feature Store (online)
│   ├── CloudWatch alarms
│   └── Data capture (S3)
├── Onboarding time: 3 days
└── Customization: Client provides model artifact + feature schema

Blueprint 3: Batch Scoring Pipeline
├── Terraform module: sagemaker-batch-scoring/
│   ├── Step Functions (orchestration)
│   ├── SageMaker Batch Transform
│   ├── S3 (input/output)
│   ├── EventBridge (schedule)
│   ├── SNS (notifications)
│   └── Glue Catalog (output schema)
├── Onboarding time: 1 day
└── Customization: Client provides model + input data location

Blueprint 4: Document Processing Pipeline
├── Terraform module: intelligent-document-processing/
│   ├── Textract + Comprehend
│   ├── Step Functions
│   ├── Bedrock (summarization/classification)
│   ├── A2I (human review)
│   ├── DynamoDB (results)
│   └── S3 (documents)
├── Onboarding time: 2 days
└── Customization: Client provides doc types + extraction rules
```

**Onboarding Workflow:**

```
New AI Project Request
    ↓
AI CoE reviews → selects blueprint
    ↓
Fill out onboarding form (project name, team, data classification, budget)
    ↓
Terraform workspace created → terraform apply → AWS account provisioned
    ↓
Team gets SageMaker Studio access + S3 buckets + IAM roles
    ↓
Begin development (Sandbox → PoC → Pilot → Prod)
```

---

## 9. Policy-as-Code & Governance Automation

### Q55: How do you implement policy-as-code for AI cloud governance?

**Answer:**

```
POLICY-AS-CODE STACK:

1. TERRAFORM GUARDRAILS (pre-deployment):
   ├── Sentinel (HashiCorp) or OPA (Open Policy Agent)
   │
   │   Example Sentinel policy:
   │   ┌─────────────────────────────────────────────────────────┐
   │   │ # Enforce KMS encryption on all SageMaker resources     │
   │   │ import "tfplan/v2" as tfplan                            │
   │   │                                                         │
   │   │ sagemaker_resources = filter tfplan.resource_changes as │
   │   │   _, rc { rc.type is "aws_sagemaker_endpoint_config" }  │
   │   │                                                         │
   │   │ main = rule {                                           │
   │   │   all sagemaker_resources as _, rc {                    │
   │   │     rc.change.after.kms_key_arn is not null             │
   │   │   }                                                     │
   │   │ }                                                       │
   │   └─────────────────────────────────────────────────────────┘

2. AWS CONFIG RULES (runtime compliance):
   ├── sagemaker-endpoint-configuration-kms-key-configured
   ├── s3-bucket-server-side-encryption-enabled
   ├── iam-policy-no-statements-with-admin-access
   ├── vpc-flow-logs-enabled
   └── Custom rules (Lambda-backed):
       ├── "All SageMaker endpoints must have Model Monitor enabled"
       ├── "All Bedrock model access must go through VPC endpoint"
       └── "All S3 buckets must have cost allocation tags"

3. SERVICE CONTROL POLICIES (SCPs — account-level):
   ├── Deny: launch GPU instances in Sandbox accounts
   ├── Deny: create public S3 buckets in any AI account
   ├── Deny: create IAM users (force SSO)
   ├── Deny: disable CloudTrail
   └── Deny: create resources outside approved regions

4. IAM PERMISSION BOUNDARIES:
   ├── AI Developer: can create SageMaker resources, not IAM roles
   ├── AI Platform Engineer: can manage infrastructure, not data
   └── AI Admin: full access within permission boundary scope
```

---

## 10. ECS, EventBridge & Serverless AI Patterns

### Q56: How do you use ECS for AI workloads? (JD lists ECS alongside EKS)

**Answer:**

```
ECS FOR AI WORKLOADS:

1. AI INFERENCE API (ECS Fargate):
   ┌────────────┐    ┌──────────────┐    ┌──────────────┐
   │ API Gateway │ →  │ ECS Fargate  │ →  │ Bedrock /    │
   │ (REST)      │    │ (FastAPI /   │    │ SageMaker    │
   │             │    │  LangChain)  │    │ Endpoint     │
   └────────────┘    └──────────────┘    └──────────────┘
   
   Why ECS over Lambda for AI:
   ├── Sustained connections (WebSocket for streaming LLM)
   ├── Larger memory (up to 120GB vs Lambda's 10GB)
   ├── Custom containers with ML libraries (PyTorch, etc.)
   ├── Persistent connections to vector DB / feature store
   └── GPU support (ECS on EC2 with GPU instances)

2. BATCH PROCESSING (ECS on EC2 with GPU):
   ├── Embedding generation (batch process 1M documents)
   ├── Model inference on large datasets
   └── Spot instances for cost optimization

3. MLFLOW SERVER (ECS Fargate):
   ├── Long-running service (not suitable for Lambda)
   ├── Backed by RDS PostgreSQL + S3
   └── Auto-scaling based on active experiments
```

---

### Q57: How do you use EventBridge in AI platform architectures?

**Answer:**

```
EVENTBRIDGE IN AI PLATFORM:

1. MODEL LIFECYCLE EVENTS:
   SageMaker Model Registry status change
   → EventBridge rule
   → Step Functions (start deployment pipeline)
   → SNS (notify approvers)

2. DATA ARRIVAL TRIGGERS:
   S3 object created (new training data)
   → EventBridge rule
   → Step Functions (start retraining pipeline)

3. SCHEDULED OPERATIONS:
   EventBridge Scheduler
   → Lambda (nightly model evaluation)
   → Lambda (weekly data quality report)
   → Step Functions (monthly model revalidation)

4. COST ALERTS:
   AWS Budgets threshold exceeded
   → EventBridge
   → Lambda (auto-scale down non-prod endpoints)
   → SNS (alert FinOps team)

5. SECURITY EVENTS:
   GuardDuty finding (anomalous API call to Bedrock)
   → EventBridge
   → Lambda (quarantine IAM role)
   → SNS (alert security team)
```

---

## 11. AI Observability & Operational Governance

### Q58: How do you implement comprehensive AI observability on AWS?

**Answer:**

```
AI OBSERVABILITY STACK:

┌──────────────────────────────────────────────────────────┐
│  AWS MANAGED GRAFANA (Primary Dashboard)                  │
│                                                           │
│  Dashboard 1: AI Platform Health                          │
│  ├── SageMaker endpoint status (all endpoints)           │
│  ├── Bedrock API availability                             │
│  ├── Feature Store latency (online store p99)            │
│  └── ECS/EKS service health                              │
│                                                           │
│  Dashboard 2: Model Performance                           │
│  ├── Prediction latency (p50, p95, p99)                  │
│  ├── Throughput (invocations/sec per model)               │
│  ├── Error rate (4xx, 5xx)                               │
│  ├── Data drift score (Model Monitor)                    │
│  └── Model quality metrics (accuracy, F1 over time)      │
│                                                           │
│  Dashboard 3: GenAI / LLM Metrics                         │
│  ├── Token usage (input + output per model)               │
│  ├── Cost per query (calculated from token pricing)      │
│  ├── Guardrail intervention rate                         │
│  ├── Hallucination rate (grounding score)                │
│  └── Latency per model (TTFT + total response time)      │
│                                                           │
│  Dashboard 4: Cost & Governance                           │
│  ├── Daily spend by service (SageMaker, Bedrock, S3)     │
│  ├── Spend by project/team (cost allocation tags)        │
│  ├── Unused resources (idle endpoints)                    │
│  └── Budget vs. actual (per environment)                 │
└──────────────────────────────────────────────────────────┘

Data Sources:
  ├── CloudWatch Metrics (SageMaker, Bedrock, ECS)
  ├── CloudWatch Logs Insights (application logs)
  ├── Prometheus (EKS workloads via AMP)
  ├── X-Ray (distributed tracing)
  └── Custom metrics (Lambda → CloudWatch custom namespace)
```

---

## 12. AWS Control Tower Deep Dive

### Q59: How do you use AWS Control Tower to govern AI platform accounts?

**Answer:**

```
CONTROL TOWER FOR AI PLATFORM:

Landing Zone Structure:
  Root
  ├── Security OU (mandatory)
  │   ├── Log Archive
  │   └── Audit
  ├── Infrastructure OU
  │   ├── Network Hub
  │   └── Shared Services (ECR, MLflow, CI/CD)
  ├── AI Platform OU ← NEW (AI-specific)
  │   ├── AI Sandbox Account(s)
  │   ├── AI Dev Account
  │   ├── AI Pilot Account
  │   └── AI Production Account
  └── Analytics OU
      ├── Databricks Account
      └── Data Lake Account

Control Tower Features I Configure:
  ├── Account Factory: Self-service account provisioning
  │   ├── AI account vending machine (Terraform + Account Factory)
  │   ├── Pre-configured VPC, IAM roles, S3 buckets
  │   └── SageMaker Domain auto-provisioned
  ├── Guardrails (Preventive + Detective):
  │   ├── Preventive: Deny public S3, deny root access
  │   ├── Detective: Detect unencrypted S3, detect unused IAM roles
  │   └── Custom: Detect SageMaker without VPC, detect Bedrock without guardrails
  └── Customizations for Control Tower (CfCT):
      ├── Deploy baseline Terraform to each new AI account
      ├── Configure VPC endpoints for SageMaker, Bedrock
      └── Set up CloudWatch dashboards and alarms
```

---

## 13. AI Cost Governance & Tagging

### Q60: How do you implement AI cost governance with tagging strategies?

**Answer:**

```
AI COST GOVERNANCE FRAMEWORK:

MANDATORY TAGS (enforced via SCP + AWS Config):
┌───────────────────┬──────────────────────┬────────────────────────────┐
│ Tag Key           │ Example Values       │ Purpose                    │
├───────────────────┼──────────────────────┼────────────────────────────┤
│ Project           │ fraud-detection-v3   │ Cost allocation to project │
│ Team              │ ai-engineering       │ Cost allocation to team    │
│ Environment       │ sandbox/dev/pilot/prod│ Environment tracking      │
│ CostCenter        │ CC-4521              │ Finance chargeback         │
│ AIWorkloadType    │ training/inference/  │ AI-specific cost analysis  │
│                   │ data-prep/genai      │                            │
│ ModelName         │ fraud-xgboost-v3     │ Per-model cost tracking    │
│ DataClassification│ restricted/internal  │ Compliance                 │
│ ExpiryDate        │ 2024-12-31           │ Auto-cleanup (sandbox)     │
└───────────────────┴──────────────────────┴────────────────────────────┘

COST OPTIMIZATION CONTROLS:
├── Sandbox: Auto-terminate resources after 30 days (Lambda + EventBridge)
├── Dev: Shut down SageMaker endpoints after business hours (6 PM → 9 AM)
├── Pilot: Right-size based on Compute Optimizer
├── Prod: Savings Plans + Reserved Capacity for steady-state

AI-SPECIFIC COST METRICS:
├── Cost per training run ($X per model version)
├── Cost per inference ($/1000 invocations)
├── Cost per token (Bedrock — input vs output)
├── Infrastructure cost vs AI cost ratio
└── Idle resource waste (endpoints with < 10 invocations/day)
```

---

## 14. Responsible AI & Model Risk Management

### Q61: How do you implement Responsible AI and model risk management?

**Answer:**

```
RESPONSIBLE AI FRAMEWORK:

1. BIAS & FAIRNESS:
   ├── Pre-training: SageMaker Clarify bias metrics
   │   ├── Class Imbalance (CI)
   │   ├── Difference in Positive Proportions in Labels (DPL)
   │   └── Kolmogorov-Smirnov (KS) test
   ├── Post-training:
   │   ├── Disparate Impact (DI)
   │   ├── Equal Opportunity Difference (EOD)
   │   └── Demographic Parity Difference (DPD)
   └── Runtime: Continuous bias monitoring (Model Monitor)

2. EXPLAINABILITY:
   ├── SageMaker Clarify (SHAP values for feature importance)
   ├── Counterfactual explanations
   ├── Model Cards (standardized documentation)
   └── Human-readable explanations for business stakeholders

3. MODEL RISK MANAGEMENT (SR 11-7 / OCC 2011-12 for banking):
   ├── Model Inventory: All models cataloged in Model Registry
   ├── Risk Tiering:
   │   ├── Tier 1 (High): Credit decisions, fraud blocking — quarterly validation
   │   ├── Tier 2 (Medium): Recommendations, routing — semi-annual validation
   │   └── Tier 3 (Low): Internal tooling, analytics — annual validation
   ├── Validation: Independent model validation team reviews
   ├── Documentation: Model card + technical report + validation report
   └── Sunset: Defined model decommission process

4. GENAI-SPECIFIC RESPONSIBLE AI:
   ├── Bedrock Guardrails (content filtering, PII blocking)
   ├── Red teaming (adversarial prompt testing before launch)
   ├── Human-in-the-loop for high-stakes decisions
   ├── Transparency: Users know they're interacting with AI
   └── Grounding checks: Ensure factual accuracy (anti-hallucination)
```

---

## 15. Updated Behavioral Answers (JD-Aligned)

### Q62: Updated "Tell me about yourself" (aligned to JD's AI platform focus)

**Answer:**  
"I'm an Enterprise Cloud and AI Architect with 12+ years of experience, with the last 5 years focused heavily on AWS cloud architecture and AI platform engineering.

My core expertise areas that directly map to this role:

1. **AI Platform Architecture**: I've designed and implemented stage-gated AI environments spanning Sandbox through Production on AWS — using Control Tower for governance, SageMaker for ML workloads, and Bedrock for GenAI enablement.

2. **SageMaker Hands-on**: I've built end-to-end MLOps pipelines using SageMaker Pipelines, Model Registry, Feature Store, and Model Monitor. I've trained and fine-tuned LLMs using SageMaker with Hugging Face integration and QLoRA for cost-efficient fine-tuning.

3. **Enterprise Governance**: I've established AI SDLC standards with approval gates, implemented policy-as-code using OPA/Sentinel for Terraform, and configured IAM Identity Center, SCPs, and Config Rules for compliance enforcement.

4. **Infrastructure as Code**: All my architectures are Terraform-first — from multi-account landing zones to SageMaker endpoint configurations with auto-scaling and model monitoring.

5. **GenAI Enablement**: I've built RAG architectures using LangChain + Bedrock + OpenSearch, with Bedrock Guardrails for PII protection and content safety — exactly the kind of enterprise GenAI platform this role requires.

I'm excited about EXL because the role requires building a standardized AI platform that multiple project teams can onboard to safely — that's the exact challenge I enjoy most: building reusable, governed, enterprise-grade platforms."

---

### Q63: Updated "complex architecture" example (AI platform focus instead of multi-cloud)

**Answer:**  
"The most relevant architecture I designed was an **enterprise AI platform** for a financial services client that needed to support 15+ AI/ML projects across 200+ data scientists:

**Challenge:** Every team was running their own SageMaker instances with no standardization — security gaps, cost overruns ($400K/month with 60% waste), no model governance, and compliance violations.

**What I built:**

1. **Stage-gated environment architecture**: 4-account setup (Sandbox/Dev/Pilot/Prod) with automated provisioning via Control Tower Account Factory + Terraform

2. **Reusable blueprints**: 4 Terraform modules (RAG chatbot, real-time inference, batch scoring, IDP) — new projects onboarded in 2 days instead of 4 weeks

3. **AI SDLC enforcement**: SageMaker Model Registry approval gates, mandatory model cards, SageMaker Clarify bias reports required before Pilot promotion

4. **Cost governance**: Mandatory tagging, auto-shutdown of non-prod endpoints, Managed Grafana cost dashboards — reduced monthly spend from $400K to $160K

5. **Security hardening**: VPC-only SageMaker, KMS CMK encryption everywhere, Bedrock via VPC endpoints, Policy-as-Code for Terraform

**Trade-offs:**

| Decision | Trade-off |
|----------|-----------|
| Strict approval gates | Slower initial deployment, but zero compliance incidents |
| Terraform-only provisioning | Teams couldn't self-service, but infrastructure was consistent |
| Centralized MLflow (vs per-team) | Single point of failure, but unified experiment tracking |

**Outcome:** Platform served 15 projects, 200+ users, passed SOX audit, and reduced AI infrastructure costs by 60%."

---

## JD Coverage Checklist

| JD Requirement | Original File | Supplemental File | Status |
|---------------|--------------|-------------------|--------|
| Stage-gated environments (Sandbox→Prod) | ❌ | ✅ Q41-Q42 | **Fixed** |
| AI SDLC standards & approval gates | ❌ | ✅ Q43-Q44 | **Fixed** |
| Multi-account AWS (Organizations, Control Tower) | ⚠️ Surface | ✅ Q59 (deep) | **Fixed** |
| IAM Identity Center | ⚠️ Mentioned | ✅ Q45 governance | **Fixed** |
| AI governance guardrails | ⚠️ Partial | ✅ Q45 (full framework) | **Fixed** |
| Reusable architecture blueprints | ❌ | ✅ Q54 | **Fixed** |
| ECS for AI workloads | ❌ | ✅ Q56 | **Fixed** |
| EventBridge patterns | ❌ | ✅ Q57 | **Fixed** |
| Managed Grafana | ❌ | ✅ Q58 | **Fixed** |
| LLMOps patterns | ❌ | ✅ Q46-Q47 | **Fixed** |
| Databricks experience | ❌ | ✅ Q48-Q49 | **Fixed** |
| Unity Catalog | ❌ | ✅ Q49 | **Fixed** |
| LangChain | ⚠️ Mentioned | ✅ Q50 (code example) | **Fixed** |
| MLflow | ❌ | ✅ Q51 | **Fixed** |
| Kubeflow | ❌ | ✅ Q52 | **Fixed** |
| Vector databases & embeddings | ⚠️ Partial | ✅ Q53 (full comparison) | **Fixed** |
| Policy-as-code | ❌ | ✅ Q55 | **Fixed** |
| AI cost governance & tagging | ⚠️ Generic | ✅ Q60 (AI-specific) | **Fixed** |
| Responsible AI & model risk | ⚠️ Brief | ✅ Q61 (SR 11-7) | **Fixed** |
| AI observability | ❌ | ✅ Q58 | **Fixed** |
| Secrets management | ⚠️ Brief | ✅ Q45 (detailed) | **Fixed** |
| Data classification controls | ❌ | ✅ Q45 | **Fixed** |
| Bedrock / SageMaker | ✅ Deep | ✅ Maintained | ✅ |
| VPC / Security / KMS | ✅ | ✅ | ✅ |
| Terraform IaC | ✅ | ✅ | ✅ |
| DevSecOps / CI/CD | ✅ | ✅ | ✅ |
| SQS/SNS/S3/DynamoDB | ✅ | ✅ | ✅ |
| Behavioral/leadership | ✅ | ✅ Q62-Q63 (updated) | **Fixed** |

---

**Prepared:** June 2026 | **Candidate:** Pushparaj Naik | **Role:** Enterprise AI Cloud Architect — EXL Services
