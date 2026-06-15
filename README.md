# AWS · Kubernetes · DevOps — Production-Grade Portfolio

> **Author:** [Pushparaj Naik](https://github.com/pusnaik2016)
> **Repository:** [`pusnaik2016/aws_k8s_devops`](https://github.com/pusnaik2016/aws_k8s_devops)
> **Focus:** Cloud Architecture · DevSecOps · Infrastructure as Code · Kubernetes · Serverless AI · Multi-Cloud · IoT Edge Computing

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5-623CE4?logo=terraform)](https://terraform.io)
[![AWS](https://img.shields.io/badge/Cloud-AWS-FF9900?logo=amazonaws)](https://aws.amazon.com/)
[![Azure](https://img.shields.io/badge/Cloud-Azure-0078D4?logo=microsoft-azure)](https://azure.microsoft.com/)
[![GCP](https://img.shields.io/badge/Cloud-GCP-4285F4?logo=google-cloud)](https://cloud.google.com/)
[![Kubernetes](https://img.shields.io/badge/Orchestration-Kubernetes-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![GitHub Actions](https://img.shields.io/badge/CI%2FCD-GitHub_Actions-2088FF?logo=github-actions&logoColor=white)](https://github.com/features/actions)
[![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-EF7B4D?logo=argo&logoColor=white)](https://argoproj.github.io/cd/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## 📌 About This Repository

This mono-repository is a curated collection of **12 production-grade cloud infrastructure projects** that showcase end-to-end cloud architecture, DevSecOps pipelines, Kubernetes orchestration, serverless AI solutions, multi-cloud platforms, and IoT edge computing — all implemented with **Infrastructure as Code (Terraform)** and **GitOps** best practices.

Each project is self-contained with its own README, Terraform modules, CI/CD pipelines, and documentation. Together, they demonstrate expertise across the AWS Well-Architected Framework pillars: **Operational Excellence**, **Security**, **Reliability**, **Performance Efficiency**, **Cost Optimization**, and **Sustainability**.

---

## 🗂️ Repository Structure

```
aws_k8s_devops/
│
├── ansible-config-mgmt/                          # 📁 **Automated infrastructure provisioning, security hardening,
├── aws-cost-anomaly-detector/                    # 🔍 **Intelligent AWS cost monitoring for ~$2/month** — powered 
├── bedrock-agent-memory-system/                  # 🤖 **Build AI Agents That Actually Remember** — A production-gr
├── bedrock-rag-chatbot/                          # 🤖 **Author:** Pushparaj Naik
├── claude-code-devops-workflows/                 # 🤖 **"Stop babysitting your automation. Configure your AI agent
├── devops-debug-toolkit/                         # 🔧 **10-in-1 DevOps Automation Toolkit** — Scan, Debug, Optimiz
├── eks-gitops-quiz-app/                          # 🌐 Production-ready 3-tier application deployed on AWS EKS with
├── eks-multiregion-devsecops/                    # 🌐 Production-grade, multi-region AWS infrastructure for a Java
├── interview-prep-docs/                          # 📚 Project directory
├── iot-greengrass-edge-telemetry/                # 📡 **Production-grade IoT edge connectivity using AWS IoT Core 
├── java-eks-devsecops-pipeline/                  # 🌐 **End-to-end CI/CD pipeline** using GitHub Actions, private 
├── medcloud-global-platform/                     # 📁 **Multi-Cloud Healthcare & Medical E-Commerce Platform** — A
├── multicloud-clearing-engine/                   # 🏗️ This system implements a **three-cloud active/standby/compli
└── omnichannel-ai-support-platform/              # 🤖 **Next-gen, self-healing customer service system** — Generat
└── README.md                                     # ← You are here
```

---

## 🏗️ Projects at a Glance

### 1. 🌐 [3-Tier DevOps Quiz Application on AWS EKS](./eks-gitops-quiz-app/)

> Production-ready 3-tier application (React + Flask + PostgreSQL) deployed on AWS EKS with full GitOps automation via ArgoCD.

| Aspect | Details |
|--------|---------|
| **Architecture** | React 18 frontend → Flask/Gunicorn REST API → AWS RDS PostgreSQL 14 |
| **Orchestration** | AWS EKS 1.31 with HPA, PDB, and External Secrets Operator |
| **GitOps** | ArgoCD App-of-Apps pattern with automated drift detection and self-healing |
| **Secrets** | External Secrets Operator syncing from AWS Secrets Manager (no base64 in Git) |
| **Networking** | ALB Ingress with Route53, ACM TLS certificates, and WAF protection |
| **Monitoring** | Prometheus + Grafana full observability stack via Helm |
| **Compliance** | CloudTrail, GuardDuty, AWS Config — GDPR/SOC2 aligned |
| **DR** | Cross-region RDS snapshots, Multi-AZ — RPO < 1hr, RTO < 4hr |
| **CI/CD** | GitHub Actions (OIDC) → ECR → Git tag update → ArgoCD auto-sync |
| **IaC** | Terraform with S3 + DynamoDB remote state locking |

**Key Principle:** The CI pipeline **never** runs `kubectl apply`. It only updates image tags in Git. ArgoCD detects the commit and reconciles the cluster state — true GitOps.

---

### 2. 🛡️ [Multi-Region EKS DevSecOps Infrastructure](./eks-multiregion-devsecops/)

> Multi-region (us-east-1 + ap-south-1) AWS infrastructure for a Java ecommerce application on private EKS clusters with Aurora Global Database and comprehensive security scanning.

| Aspect | Details |
|--------|---------|
| **Multi-Region** | Primary (us-east-1) + DR (ap-south-1) with Route53 failover routing |
| **Compute** | Private EKS clusters with Karpenter autoscaling for right-sized nodes |
| **Database** | Aurora Global Database — cross-region replication with < 1s RPO |
| **Autoscaling** | HPA (CPU + memory targets) + Karpenter (spot instances, bin-packing) |
| **Encryption** | KMS CMK for EKS secrets, EBS volumes, Aurora, CloudWatch Logs, S3, SNS, SQS |
| **Security Scanning** | Gitleaks (secrets), SonarCloud (SAST), OWASP DC (SCA), Trivy (containers), Checkov (IaC) |
| **Monitoring** | CloudWatch, GuardDuty, Security Hub, AWS Config |
| **Networking** | Private subnets only, VPC Endpoints, VPC Flow Logs |
| **Compliance** | PCI DSS, HIPAA, SOC 2 aligned security controls |
| **CI/CD** | GitHub Actions — Terraform IaC + Java App CI + Helm CD pipelines |

**Well-Architected Alignment:** Reliability (Multi-region + Aurora Global), Security (KMS + GuardDuty + least-privilege), Performance (Karpenter spot), Operational Excellence (full DevSecOps), Cost Optimization (Karpenter bin-packing + spot).

---

### 3. ☕ [Java DevSecOps Pipeline — Production Architecture](./java-eks-devsecops-pipeline/)

> End-to-end CI/CD pipeline with 12-stage GitHub Actions CI, private EKS, ArgoCD GitOps, WAF v2, API Gateway, and Cognito authentication — fully automated with Terraform.

| Aspect | Details |
|--------|---------|
| **Pipeline** | 12-stage CI (build → test → SAST → SCA → container scan → push) + GitOps CD |
| **Security Layers** | 12-layer defense-in-depth: Route53 → WAF → API GW → Cognito → ALB → Private EKS → IMDSv2 → KMS → IRSA → OIDC |
| **GitOps** | ArgoCD with auto-heal and prune policies — self-correcting cluster state |
| **Authentication** | Cognito User Pools with OAuth2, hosted UI, JWT validation at API Gateway |
| **WAF** | WAF v2 Web ACL with OWASP Top 10 rules, SQLi protection, rate limiting |
| **Network** | Private EKS (kubectl only from bastion), 6 VPC Endpoints (PrivateLink) |
| **Auth to AWS** | GitHub OIDC — keyless, no stored credentials |
| **Cost** | ~$235/month (saves ~$100 vs Jenkins architecture — no Jenkins/SonarQube EC2) |

**Security Flow:** `Client → Route53 → WAF (OWASP) → API Gateway (Cognito JWT) → ALB (HTTPS) → EKS Pod`

---

### 4. 🏗️ [Multi-Cloud Healthcare & Financial Clearing Engine](./multicloud-clearing-engine/)

> Production-grade multi-cloud infrastructure (AWS + Azure + GCP) for ingesting, validating, and clearing sensitive medical billing transactions with HIPAA, SOX, GDPR, and PCI-DSS compliance.

| Aspect | Details |
|--------|---------|
| **Architecture** | Three-cloud: AWS (primary active) + Azure (hot standby) + GCP (compliance & analytics) |
| **Microservices** | 4 Python/FastAPI services: transaction-ingestion, clearing-engine-core, audit-pipeline, notification-service |
| **Compute** | EKS + AKS + GKE — all private clusters, Istio STRICT mTLS service mesh |
| **Databases** | Aurora PostgreSQL (primary), Azure SQL Hyperscale (standby), AlloyDB + BigQuery (compliance) |
| **Caching** | ElastiCache Redis (3 shards × 2 replicas) + Azure Cache for Redis Premium |
| **Networking** | Cross-cloud IPSec VPN mesh (IKEv2, AES-256-GCM, BGP dynamic routing) |
| **Security** | Azure AD centralized identity, KMS/Key Vault/Cloud KMS encryption, private endpoints everywhere |
| **Compliance** | HIPAA + SOX + GDPR + PCI-DSS controls: immutable audit trail, PII tokenization, data sovereignty |
| **GitOps** | ArgoCD on all 3 clusters with Istio egress policies |
| **CI/CD** | 5 GitHub Actions pipelines: 3 infra (per cloud) + app CI + app CD |
| **DR** | RTO 5 min, RPO 0 (sync replication) — Route53 auto-failover to Azure |

**Scale:** Full Helm umbrella chart with 4 subcharts, HPA (3–20 replicas), PDB, zero-trust NetworkPolicies.

---

### 5. 🤖 [Omnichannel AI Customer Support Platform](./omnichannel-ai-support-platform/)

> Enterprise AI-powered customer support system with real-time WebSocket chat (Bedrock Claude 3.5), human escalation, and sentiment analytics — deployed on EKS with KEDA event-driven scaling.

| Aspect | Details |
|--------|---------|
| **AI Chat** | WebSocket-based real-time chat powered by Amazon Bedrock (Claude 3.5 Sonnet) with RAG context from pgvector |
| **Human Escalation** | Automatic routing to human agents when AI confidence is low or sentiment turns negative |
| **Sentiment Analytics** | Async analysis pipeline scoring every conversation for sentiment, topics, and CSAT proxy metrics |
| **Caching** | Redis cache layer saves ~40% Bedrock API costs |
| **Vector DB** | pgvector in Aurora PostgreSQL (no separate OpenSearch/Pinecone service) |
| **Scaling** | KEDA event-driven scaling on Redis queue depth + HPA for CPU |
| **Security** | GitHub OIDC + IRSA — zero static AWS credentials anywhere |
| **Frontend** | React 18 + Vite chat widget served via CloudFront + S3 |
| **IaC** | 5 Terraform modules: networking, security, compute, database, ai_cdn |
| **Cost** | ~$458–$608/month (production estimate) |

**Key Differentiator:** Combines LLM cost optimization (Redis caching), event-driven autoscaling (KEDA), and pgvector-in-Aurora (no extra vector DB service) for a cost-efficient AI platform.

---

### 6. 🧠 [3-Layer Memory System for Bedrock Agents](./bedrock-agent-memory-system/)

> Production-grade 3-layer memory architecture for Amazon Bedrock Agents — in-context memory, SESSION_SUMMARY, and long-term knowledge base backed by Aurora pgvector. Fully deployed with Terraform.

| Aspect | Details |
|--------|---------|
| **Layer 1** | In-Context Memory — 0ms latency, current invocation only, zero config |
| **Layer 2** | SESSION_SUMMARY — ~50ms, Bedrock-managed, 30-day retention, within-session |
| **Layer 3** | Knowledge Base — ~310ms, indefinite retention, cross-session, Aurora pgvector |
| **Memory Writer** | Lambda-based action group with confidence gate (≥ 0.7 saves, < 0.7 skips) |
| **Categories** | preference, project_context, decision, user_profile |
| **Storage** | Aurora Serverless v2 (pgvector), S3 (memory docs), DynamoDB (audit trail) |
| **Observability** | CloudWatch dashboard + 3 alarms |
| **IaC** | 5 Terraform modules: aurora-pgvector, knowledge-base, agent, session-memory, observability |
| **Tests** | 81 tests: Lambda handler (23), Terraform (33), Integration (25) |
| **Cost** | ~$43/month (Aurora dominant, set min_capacity=0 for dev) |

**The Problem It Solves:** Most AI agents suffer from goldfish memory — every session starts from zero. This architecture gives agents persistent, semantically searchable memory across sessions.

---

### 7. 💬 [Enterprise RAG Chatbot on Amazon Bedrock](./bedrock-rag-chatbot/)

> Serverless Retrieval-Augmented Generation (RAG) chatbot using Amazon Bedrock (Claude 3.5 Sonnet + Titan Embed v2) with OpenSearch Serverless vector search, Bedrock Guardrails, and zero NAT Gateway costs.

| Aspect | Details |
|--------|---------|
| **LLM** | Claude 3.5 Sonnet v2 via Amazon Bedrock |
| **Embeddings** | Amazon Titan Embed v2 (1024-dimensional vectors) |
| **Vector Store** | OpenSearch Serverless with kNN search |
| **Generation Strategies** | RAG (embed → search → generate) and CAG (prompt caching — 90% cheaper) |
| **Ingestion** | S3 event trigger → Lambda → semantic chunking → Titan Embed → OpenSearch index |
| **Security** | Private subnets only, VPC Endpoints (no NAT GW), KMS CMK encryption, Bedrock Guardrails (PII redaction, content filtering, topic denial) |
| **API** | API Gateway (REST) with CORS, optional Cognito auth |
| **Cost** | ~$60/month (dev) — VPC Endpoints save ~$32+ vs NAT Gateway |
| **CI/CD** | GitHub Actions — lint → validate → Checkov scan → plan/apply |

**Dual Strategy:** RAG for large knowledge bases (1000+ pages) and CAG for small, frequently-queried content (< 100 pages) with **90% cost reduction** via prompt caching.

---

### 8. 🔍 [AWS Cost Anomaly Detector](./aws-cost-anomaly-detector/)

> Intelligent AWS cost monitoring for ~$2/month — powered by Z-score statistics and Claude 3.5 Sonnet via Amazon Bedrock. Tells you **WHY** your bill spiked, not just **THAT** it did.

| Aspect | Details |
|--------|---------|
| **Detection** | Z-score statistical analysis per AWS service (configurable threshold: 2.0–3.0) |
| **AI Analysis** | Claude 3.5 Sonnet provides severity, root cause, and actionable AWS CLI commands |
| **Data Pipeline** | EventBridge → Lambda → Cost Explorer API (90 days) → DynamoDB (TTL auto-expiry) |
| **Alerting** | SNS email alerts with both raw statistics and Claude's analysis |
| **Baseline** | 90-day rolling baseline, excludes today's cost, 14-day minimum per service |
| **Cost** | ~$1–$2/month total (Lambda free tier, DynamoDB PAY_PER_REQUEST, minimal Bedrock tokens) |
| **IaC** | 4 Terraform modules: storage, bedrock_config, notifications, cost_analyzer |
| **Deploy** | One-command deployment: `./deploy.sh` |

**How It Works:**
```
EventBridge (08:00 UTC) → Cost Fetcher Lambda → Cost Explorer API → DynamoDB
EventBridge (08:10 UTC) → Anomaly Detector Lambda → Z-score analysis → Bedrock Claude → SNS Alert
```

---

### 9. 📡 [IoT Greengrass v2 — Edge Telemetry PoC](./iot-greengrass-edge-telemetry/)

> Production-grade IoT edge connectivity using AWS IoT Core and Greengrass v2, featuring device security (X.509 certificates, mTLS), edge processing, and telemetry flows across multi-site deployments.

| Aspect | Details |
|--------|---------|
| **Edge Runtime** | AWS IoT Greengrass v2 Nucleus with modular Python components |
| **Edge Processing** | Sensor Collector + Telemetry Processor — 80% bandwidth reduction via edge aggregation |
| **Device Security** | X.509 certificate-based mutual TLS, least-privilege MQTT policies, Token Exchange Service |
| **Telemetry Pipeline** | MQTT → IoT Rules Engine → S3 (archive) + Timestream (analytics) + Lambda (alerting) |
| **Fleet Management** | Thing Groups for multi-site (Mumbai, Bangalore, Delhi) coordinated deployments |
| **Storage** | S3 lifecycle (Standard → IA → Glacier → Expire) + Timestream (24h memory, 365d magnetic) |
| **Monitoring** | CloudWatch dashboard, alarms, Lambda error rate tracking |
| **Encryption** | KMS CMK for S3, Timestream, CloudWatch Logs, SNS |
| **IaC** | 7 Terraform modules with remote state + DynamoDB locking |
| **Cost Savings** | ~$304/month saved (98% reduction) with edge aggregation vs raw cloud ingestion |

**Well-Architected Scores:** Security ⭐⭐⭐⭐⭐ | Reliability ⭐⭐⭐⭐ | Operational Excellence ⭐⭐⭐⭐ | Performance ⭐⭐⭐⭐ | Cost Optimization ⭐⭐⭐⭐

---

### 10. 🤖 [AI-Driven DevOps Workflows with Claude Code](./claude-code-devops-workflows/)

> Autonomous AI-driven infrastructure workflows — configuring Claude Code as a DevOps agent that owns the entire pipeline from scanning to reporting, using 5 key primitives: CLAUDE.md, slash commands, hooks, agentic pipelines, and MCP servers.

| Aspect | Details |
|--------|---------|
| **Paradigm** | Shift from prompting AI for snippets to orchestrating an autonomous DevOps agent |
| **CLAUDE.md** | Standing brief with stack rules, security policies, naming conventions, dangerous command lists |
| **Slash Commands** | `/pr-review`, `/infra-validate`, `/security-scan`, `/k8s-diagnostics` |
| **Security Scanner** | 5-engine scanner: secrets (15+ patterns), Docker, Terraform, K8s, CI/CD |
| **Quality Gates** | `pre-tool.sh` (dangerous command gatekeeper) + `pre-commit.sh` (5-check quality gate) |
| **Audit Trail** | All dangerous command decisions logged to `.claude/audit.log` |
| **Defense in Depth** | 3-layer security model: Prevention → Detection → Enforcement |
| **Dependencies** | Zero external Python dependencies — stdlib only |
| **Output Formats** | Text, Markdown, JSON for CI/CD integration |

**Core Insight:** Traditional AI usage generates code snippets. This project configures AI as an autonomous agent that executes multi-step pipelines: `diff → scan → validate → report`.

---

### 11. 🔧 [10-in-1 Offline DevOps Debug Toolkit](./devops-debug-toolkit/)

> 10 essential DevOps automation tools — IaC generation, pipeline debugging, security scanning, K8s troubleshooting, cost optimization, and more — all running 100% offline with zero API dependencies.

| Aspect | Details |
|--------|---------|
| **Tools** | IaC Generator, Pipeline Debugger, Security Scanner, Incident Triage, Server Config Analyzer, Legacy Modernizer, Runbook Generator, K8s Troubleshooter, Release Notes Generator, Cost Optimizer |
| **Rules Engine** | YAML-driven: 66 detection rules across 5 rule files (customizable, version-controllable) |
| **Output Formats** | Terminal (colorized), JSON, Markdown, HTML Dashboard (Chart.js) |
| **Architecture** | Uniform `Input → Analyzer → Findings → Reporter` model for all 10 tools |
| **Offline** | 100% offline — no API keys, no cloud accounts, no internet required |
| **Speed** | 0.33s for 70 tests |
| **Tests** | 70/70 tests passing across all 10 tools |
| **Extensibility** | Add new tools by extending `BaseAnalyzer` + YAML rules + CLI registration |
| **Dependencies** | PyYAML, Rich, Click, Jinja2, pytest |

**Key Differentiator:** Your code never leaves your machine. YAML-based rules you own and version control vs vendor-locked cloud scanning tools.

---

## 🧰 Technology Stack Summary

### Cloud & Infrastructure

| Technology | Used In | Purpose |
|------------|---------|---------|
| **AWS EKS** | eks-gitops-quiz-app, eks-multiregion-devsecops, java-eks-devsecops-pipeline, omnichannel-ai-support-platform | Managed Kubernetes orchestration |
| **AWS Aurora / RDS** | eks-gitops-quiz-app, eks-multiregion-devsecops, omnichannel-ai-support-platform, bedrock-agent-memory-system | Managed relational databases |
| **Amazon Bedrock** | bedrock-rag-chatbot, aws-cost-anomaly-detector, bedrock-agent-memory-system, omnichannel-ai-support-platform | Managed LLM inference (Claude, Titan) |
| **OpenSearch Serverless** | bedrock-rag-chatbot | Vector search for RAG |
| **AWS IoT Core + Greengrass** | iot-greengrass-edge-telemetry | IoT device management + edge compute |
| **Amazon Timestream** | iot-greengrass-edge-telemetry | Time-series database for telemetry |
| **AWS Lambda** | aws-cost-anomaly-detector, bedrock-rag-chatbot, iot-greengrass-edge-telemetry, bedrock-agent-memory-system | Serverless compute |
| **API Gateway** | bedrock-rag-chatbot, java-eks-devsecops-pipeline, omnichannel-ai-support-platform | REST / WebSocket API management |
| **AWS WAF v2** | java-eks-devsecops-pipeline, eks-multiregion-devsecops, multicloud-clearing-engine | Web application firewall |
| **AWS Cognito** | java-eks-devsecops-pipeline | User authentication & JWT |
| **AWS KMS** | All infrastructure projects | Encryption key management |
| **Azure AKS** | multicloud-clearing-engine | Azure Kubernetes Service |
| **Azure SQL Hyperscale** | multicloud-clearing-engine | Azure managed database (hot standby) |
| **GCP GKE** | multicloud-clearing-engine | Google Kubernetes Engine (compliance layer) |
| **GCP BigQuery** | multicloud-clearing-engine | Audit trail analytics and compliance |
| **GCP AlloyDB** | multicloud-clearing-engine | PostgreSQL-compatible compliance database |

### DevOps & CI/CD

| Technology | Used In | Purpose |
|------------|---------|---------|
| **Terraform** | All infrastructure projects | Infrastructure as Code |
| **GitHub Actions** | All projects | CI/CD pipeline orchestration |
| **ArgoCD** | eks-gitops-quiz-app, java-eks-devsecops-pipeline, eks-multiregion-devsecops, multicloud-clearing-engine | GitOps continuous delivery |
| **Helm** | eks-multiregion-devsecops, eks-gitops-quiz-app, java-eks-devsecops-pipeline, multicloud-clearing-engine | Kubernetes package management |
| **Istio** | multicloud-clearing-engine | Service mesh with STRICT mTLS |
| **KEDA** | omnichannel-ai-support-platform | Event-driven Kubernetes autoscaling |
| **Docker** | All application projects | Containerization |
| **Amazon ECR** | All container projects | Private container registry |
| **Azure ACR** | multicloud-clearing-engine | Azure private container registry |

### Security & Compliance

| Technology | Used In | Purpose |
|------------|---------|---------|
| **Checkov** | aws-cost-anomaly-detector, bedrock-rag-chatbot, multicloud-clearing-engine | IaC security scanning |
| **Trivy** | eks-multiregion-devsecops, java-eks-devsecops-pipeline, multicloud-clearing-engine | Container vulnerability scanning |
| **SonarCloud** | eks-multiregion-devsecops, java-eks-devsecops-pipeline | Static application security testing (SAST) |
| **OWASP Dependency Check** | eks-multiregion-devsecops, java-eks-devsecops-pipeline | Software composition analysis (SCA) |
| **Gitleaks / TruffleHog** | eks-multiregion-devsecops, java-eks-devsecops-pipeline, multicloud-clearing-engine | Secrets detection in code |
| **Bedrock Guardrails** | bedrock-rag-chatbot | PII redaction, content filtering, topic denial |
| **GuardDuty** | eks-gitops-quiz-app, eks-multiregion-devsecops | Threat detection |
| **Security Hub** | eks-multiregion-devsecops | Security posture management |
| **Azure AD** | multicloud-clearing-engine | Centralized identity provider across 3 clouds |

### AI / ML

| Technology | Used In | Purpose |
|------------|---------|---------|
| **Claude 3.5 Sonnet** | bedrock-rag-chatbot, aws-cost-anomaly-detector, bedrock-agent-memory-system, omnichannel-ai-support-platform | Conversational AI, analysis, memory |
| **Titan Embeddings v2** | bedrock-rag-chatbot, omnichannel-ai-support-platform | RAG vector generation |
| **pgvector** | bedrock-agent-memory-system, omnichannel-ai-support-platform | Vector similarity search in PostgreSQL |
| **Claude Code Agent** | claude-code-devops-workflows | Autonomous DevOps agent |

### Application Frameworks

| Technology | Used In | Purpose |
|------------|---------|---------|
| **React 18** | eks-gitops-quiz-app, omnichannel-ai-support-platform | Frontend UI framework |
| **Flask / Gunicorn** | eks-gitops-quiz-app | Python REST API |
| **FastAPI** | multicloud-clearing-engine, omnichannel-ai-support-platform | High-performance Python API framework |
| **Spring Boot (Java)** | java-eks-devsecops-pipeline | Enterprise Java application |
| **Python 3.11+** | 8 projects | Serverless functions, AI agents, tooling |

---

## 🏛️ Architecture Patterns Demonstrated

| Pattern | Projects | Description |
|---------|----------|-------------|
| **GitOps** | eks-gitops-quiz-app, java-eks-devsecops-pipeline, eks-multiregion-devsecops, multicloud-clearing-engine | ArgoCD-driven declarative cluster management — CI writes to Git, ArgoCD reconciles |
| **Multi-Region DR** | eks-multiregion-devsecops | Active-passive with Route53 failover, Aurora Global DB, cross-region replication |
| **Multi-Cloud** | multicloud-clearing-engine | AWS (primary) + Azure (hot standby) + GCP (compliance) with IPSec VPN mesh |
| **Defense-in-Depth** | java-eks-devsecops-pipeline | 12-layer security stack from edge (WAF) to pod (IRSA) |
| **Event-Driven** | aws-cost-anomaly-detector, iot-greengrass-edge-telemetry, bedrock-rag-chatbot, omnichannel-ai-support-platform | EventBridge, S3 triggers, IoT Rules Engine, KEDA |
| **Edge Computing** | iot-greengrass-edge-telemetry | Greengrass v2 edge processing — 80-98% bandwidth cost reduction |
| **RAG / CAG** | bedrock-rag-chatbot | Dual generation strategies with prompt caching for cost optimization |
| **AI Agent Memory** | bedrock-agent-memory-system | 3-layer memory architecture for persistent, cross-session agent context |
| **Service Mesh** | multicloud-clearing-engine | Istio STRICT mTLS across 3 cloud providers |
| **App-of-Apps** | eks-gitops-quiz-app | ArgoCD parent application managing multiple child applications |
| **External Secrets** | eks-gitops-quiz-app | AWS Secrets Manager → K8s Secrets via ESO (no secrets in Git) |
| **OIDC Federation** | java-eks-devsecops-pipeline, omnichannel-ai-support-platform | GitHub Actions → AWS STS — keyless, credential-free CI/CD |
| **Autonomous AI Agent** | claude-code-devops-workflows | AI-driven DevOps automation with quality gates and audit logging |

---

## 📚 Technical Interview Guides & References

The [`interview-prep-docs/`](./interview-prep-docs/) directory contains comprehensive technical preparation materials covering:

- **Cloud/DevOps Architect** — AWS architecture, EKS operations, CI/CD, Terraform
- **Integration Architect** — API design, event-driven architectures, system integration
- **DevSecOps Architect** — Security scanning, compliance automation, supply chain security
- **SRE/Platform Engineer** — Observability, incident response, platform engineering
- **Solution Architect** — Well-Architected Framework, cost optimization, migration strategies
- **EKS Upgrade Guides** — Detailed EKS 1.29 → 1.31 upgrade procedures (3 parts)
- **Enterprise Architecture** — EA thinking frameworks and principal architect patterns
- **Kubernetes Complete Guide** — Comprehensive K8s reference

---

## 🚀 Getting Started

### Prerequisites

All projects require:

- **AWS CLI v2** configured with appropriate IAM permissions
- **Terraform** >= 1.5
- **Git** for version control

Individual projects may additionally require:

| Tool | Required By |
|------|------------|
| `kubectl` | EKS projects (eks-gitops-quiz-app, eks-multiregion-devsecops, java-eks-devsecops-pipeline, omnichannel-ai-support-platform) |
| `helm` | EKS projects with Helm charts, multicloud-clearing-engine |
| `docker` | All container-based projects |
| `node` (v20+) | React frontend projects |
| `python` (3.11+) | Lambda functions, AI agents, devops-debug-toolkit |

### Quick Start (Any Project)

```bash
# 1. Clone the repository
git clone https://github.com/pusnaik2016/aws_k8s_devops.git
cd aws_k8s_devops

# 2. Navigate to a specific project
cd <project-directory>

# 3. Read the project-specific README
cat README.md

# 4. Deploy infrastructure (general pattern)
cd terraform/  # or infra/
terraform init
terraform plan
terraform apply
```

> 💡 **Tip:** Each project has its own detailed README with project-specific prerequisites, deployment steps, and configuration guides. Always start there.

---

## 🔒 Security Practices

All projects in this repository follow consistent security best practices:

- ✅ **No hardcoded credentials** — AWS Secrets Manager, IRSA, OIDC federation, Token Exchange Service
- ✅ **Encryption at rest** — KMS Customer Managed Keys for all data stores
- ✅ **Encryption in transit** — TLS 1.2+ for all inter-service communication, Istio mTLS
- ✅ **Least-privilege IAM** — Scoped IAM roles per function/service
- ✅ **Private networking** — Private subnets, VPC Endpoints, no public IPs on compute
- ✅ **Security scanning** — SAST (SonarCloud), SCA (OWASP DC), container scanning (Trivy), IaC scanning (Checkov)
- ✅ **Audit logging** — CloudTrail, VPC Flow Logs, CloudWatch Logs
- ✅ **Threat detection** — GuardDuty, Security Hub, AWS Config rules
- ✅ **Multi-cloud security** — Azure AD centralized identity, Key Vault, Cloud KMS

---

## 💰 Cost Awareness

Each project includes cost estimates and optimization strategies:

| Project | Estimated Monthly Cost | Key Optimization |
|---------|----------------------|-----------------|
| aws-cost-anomaly-detector | ~$1–$2 | Free-tier Lambda, PAY_PER_REQUEST DynamoDB |
| iot-greengrass-edge-telemetry | ~$5 (edge) | Edge aggregation saves ~$304/month vs raw ingestion |
| bedrock-agent-memory-system | ~$43 | Aurora min_capacity=0 for dev (auto-pause) |
| bedrock-rag-chatbot | ~$60 (dev) | VPC Endpoints over NAT GW, CAG prompt caching |
| java-eks-devsecops-pipeline | ~$235 | No Jenkins/SonarQube EC2 (saves ~$100) |
| omnichannel-ai-support-platform | ~$458–$608 | Redis LLM cache saves ~40% Bedrock costs |
| eks-gitops-quiz-app | Variable | Karpenter spot instances, RDS reserved instances |
| multicloud-clearing-engine | Enterprise | Karpenter spot, Aurora auto-scaling, S3 lifecycle |

---

## 📄 License

MIT License — Pushparaj Naik

All projects are available for educational, demonstration, and professional portfolio purposes. Feel free to fork, modify, and learn from them.

---

**Built with precision by Pushparaj Naik** | [GitHub](https://github.com/pusnaik2016)