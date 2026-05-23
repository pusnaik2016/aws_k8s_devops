# AWS · Kubernetes · DevOps — Production-Grade Portfolio

> **Author:** [Pushparaj Naik](https://github.com/pusnaik2016)
> **Repository:** [`pusnaik2016/aws_k8s_devops`](https://github.com/pusnaik2016/aws_k8s_devops)
> **Focus:** Cloud Architecture · DevSecOps · Infrastructure as Code · Kubernetes · Serverless AI

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5-623CE4?logo=terraform)](https://terraform.io)
[![AWS](https://img.shields.io/badge/Cloud-AWS-FF9900?logo=amazonaws)](https://aws.amazon.com/)
[![Kubernetes](https://img.shields.io/badge/Orchestration-Kubernetes-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![GitHub Actions](https://img.shields.io/badge/CI%2FCD-GitHub_Actions-2088FF?logo=github-actions&logoColor=white)](https://github.com/features/actions)
[![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-EF7B4D?logo=argo&logoColor=white)](https://argoproj.github.io/cd/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## 📌 About This Repository

This mono-repository is a curated collection of **production-grade AWS infrastructure projects** that showcase end-to-end cloud architecture, DevSecOps pipelines, Kubernetes orchestration, serverless AI solutions, and IoT edge computing — all implemented with **Infrastructure as Code (Terraform)** and **GitOps** best practices.

Each project is self-contained with its own README, Terraform modules, CI/CD pipelines, and documentation. Together, they demonstrate expertise across the AWS Well-Architected Framework pillars: **Operational Excellence**, **Security**, **Reliability**, **Performance Efficiency**, **Cost Optimization**, and **Sustainability**.

---

## 🗂️ Repository Structure

```
AWS_DevOps_K8s/
│
├── 3Tier_EKS_React/                          # 🌐 3-Tier App on EKS with ArgoCD GitOps
├── EKS_DevSecOPs/                            # 🛡️ Multi-Region EKS with DevSecOps Pipelines
├── Java_DevSecOps/                           # ☕ Java DevSecOps Pipeline (WAF + Cognito + ArgoCD)
├── Bedrock_RAG/                              # 🤖 Enterprise RAG Chatbot on Amazon Bedrock
├── AnamolyDetector/                          # 🔍 AWS Cost Anomaly Detector (Bedrock + Z-score)
├── IOT_LemonGrass/                           # 📡 IoT Greengrass v2 Enterprise PoC
├── End-to-End-Deployment-Automation.../      # 🚀 ECS Fargate CI/CD with GitHub Actions
├── hackerrank-orchestrate-may26/             # 🧠 AI Support Triage Agent (Hackathon)
├── Documents/                                # 📚 Technical Interview Guides & References
└── README.md                                 # ← You are here
```

---

## 🏗️ Projects at a Glance

### 1. 🌐 [3-Tier DevOps Quiz Application on AWS EKS](./3Tier_EKS_React/)

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

### 2. 🛡️ [Multi-Region EKS DevSecOps Infrastructure](./EKS_DevSecOPs/)

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

### 3. ☕ [Java DevSecOps Pipeline — Production Architecture](./Java_DevSecOps/)

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

### 4. 🤖 [Enterprise RAG Chatbot on Amazon Bedrock](./Bedrock_RAG/)

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

### 5. 🔍 [AWS Cost Anomaly Detector](./AnamolyDetector/)

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

### 6. 📡 [AWS IoT Greengrass v2 — Enterprise PoC](./IOT_LemonGrass/)

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

### 7. 🚀 [End-to-End Deployment Automation to AWS using GitHub Actions](./End-to-End-Deployment-Automation-to-AWS-using-GitHub-Actions/)

> Campus Event Management System with a fully automated CI/CD pipeline — push to GitHub and the entire AWS infrastructure (VPC, ECS Fargate, ALB, ECR) is provisioned and deployed in under 15 minutes.

| Aspect | Details |
|--------|---------|
| **Application** | Campus event management platform (React 18 + Node.js/Express) |
| **Compute** | AWS ECS Fargate — serverless container orchestration |
| **Networking** | VPC with 2 public subnets across AZs, Internet Gateway, ALB with path-based routing |
| **CI/CD** | GitHub Actions — infrastructure provisioning + Docker build + ECR push + ECS deploy |
| **Deployment** | Zero-downtime rolling updates with ALB health check validation |
| **Docker** | Multi-stage builds (60–70% image size reduction), Nginx for frontend |
| **Routing** | ALB path-based: `/api/*` → backend (port 3000), `/*` → frontend (port 80) |
| **Security** | Three-tier security groups (ALB, backend, frontend), IAM least-privilege |
| **Idempotent** | Pipeline creates resources only when needed, updates existing ones gracefully |
| **Cleanup** | Automated resource cleanup workflow — deletes all AWS resources in 3–5 minutes |

**Key Feature:** Fully idempotent pipeline — first run provisions everything, subsequent runs only update the application. Code commit to production in ~5–7 minutes.

---

### 8. 🧠 [HackerRank Orchestrate — AI Support Triage Agent](./hackerrank-orchestrate-may26/)

> AI-powered customer support triage agent built for the HackerRank Orchestrate 24-hour hackathon. Classifies, routes, and responds to support tickets across three product ecosystems using RAG-only grounding.

| Aspect | Details |
|--------|---------|
| **Challenge** | Triage 29 real support tickets across HackerRank, Claude (Anthropic), and Visa ecosystems |
| **Retrieval** | TF-IDF vectorizer searching 774 markdown documents with company-aware boosting |
| **LLM** | Google Gemini with 6-model fallback for rate limit resilience (~12 RPM effective) |
| **Pre-Screening** | Deterministic regex patterns catch prompt injections and malicious requests before LLM |
| **Grounding** | RAG-only responses — every answer must cite from the 774-doc support corpus, no hallucination |
| **Adversarial Handling** | Detects prompt injections (English + French), malicious code requests, off-topic queries |
| **Accuracy** | 90% status accuracy, 100% request_type accuracy on sample test set |
| **Output** | Structured CSV with classification, response, justification, and escalation decisions |

**Pipeline:** `CSV Input → Regex Pre-Screen → TF-IDF Retrieve (top-5 docs) → Gemini LLM (classify + reply) → Validated CSV Output`

---

## 🧰 Technology Stack Summary

### Cloud & Infrastructure

| Technology | Used In | Purpose |
|------------|---------|---------|
| **AWS EKS** | 3Tier_EKS, EKS_DevSecOPs, Java_DevSecOps | Managed Kubernetes orchestration |
| **AWS ECS Fargate** | E2E Deployment | Serverless container orchestration |
| **AWS RDS / Aurora** | 3Tier_EKS, EKS_DevSecOPs | Managed relational databases |
| **Amazon Bedrock** | Bedrock_RAG, AnamolyDetector | Managed LLM inference (Claude, Titan) |
| **OpenSearch Serverless** | Bedrock_RAG | Vector search for RAG |
| **AWS IoT Core + Greengrass** | IOT_LemonGrass | IoT device management + edge compute |
| **Amazon Timestream** | IOT_LemonGrass | Time-series database for telemetry |
| **AWS Lambda** | AnamolyDetector, Bedrock_RAG, IOT_LemonGrass | Serverless compute |
| **API Gateway** | Bedrock_RAG, Java_DevSecOps | REST API management |
| **AWS WAF v2** | Java_DevSecOps, EKS_DevSecOPs | Web application firewall |
| **AWS Cognito** | Java_DevSecOps | User authentication & JWT |
| **AWS KMS** | All projects | Encryption key management |

### DevOps & CI/CD

| Technology | Used In | Purpose |
|------------|---------|---------|
| **Terraform** | All infrastructure projects | Infrastructure as Code |
| **GitHub Actions** | All projects | CI/CD pipeline orchestration |
| **ArgoCD** | 3Tier_EKS, Java_DevSecOps, EKS_DevSecOPs | GitOps continuous delivery |
| **Helm** | EKS_DevSecOPs, 3Tier_EKS, Java_DevSecOps | Kubernetes package management |
| **Docker** | All application projects | Containerization |
| **Amazon ECR** | All container projects | Private container registry |

### Security & Compliance

| Technology | Used In | Purpose |
|------------|---------|---------|
| **Checkov** | AnamolyDetector, Bedrock_RAG | IaC security scanning |
| **Trivy** | EKS_DevSecOPs, Java_DevSecOps | Container vulnerability scanning |
| **SonarCloud** | EKS_DevSecOPs, Java_DevSecOps | Static application security testing (SAST) |
| **OWASP Dependency Check** | EKS_DevSecOPs, Java_DevSecOps | Software composition analysis (SCA) |
| **Gitleaks** | EKS_DevSecOPs, Java_DevSecOps | Secrets detection in code |
| **Bedrock Guardrails** | Bedrock_RAG | PII redaction, content filtering, topic denial |
| **GuardDuty** | 3Tier_EKS, EKS_DevSecOPs | Threat detection |
| **Security Hub** | EKS_DevSecOPs | Security posture management |

### Application Frameworks

| Technology | Used In | Purpose |
|------------|---------|---------|
| **React 18** | 3Tier_EKS, E2E Deployment | Frontend UI framework |
| **Flask / Gunicorn** | 3Tier_EKS | Python REST API |
| **Node.js / Express** | E2E Deployment | JavaScript REST API |
| **Spring Boot (Java)** | Java_DevSecOps | Enterprise Java application |
| **Python 3.11+** | AnamolyDetector, Bedrock_RAG, IOT_LemonGrass, HackerRank | Serverless functions, AI agents |

---

## 🏛️ Architecture Patterns Demonstrated

| Pattern | Projects | Description |
|---------|----------|-------------|
| **GitOps** | 3Tier_EKS, Java_DevSecOps, EKS_DevSecOPs | ArgoCD-driven declarative cluster management — CI writes to Git, ArgoCD reconciles |
| **Multi-Region DR** | EKS_DevSecOPs | Active-passive with Route53 failover, Aurora Global DB, cross-region replication |
| **Defense-in-Depth** | Java_DevSecOps | 12-layer security stack from edge (WAF) to pod (IRSA) |
| **Event-Driven** | AnamolyDetector, IOT_LemonGrass, Bedrock_RAG | EventBridge schedules, S3 event triggers, IoT Rules Engine |
| **Edge Computing** | IOT_LemonGrass | Greengrass v2 edge processing — 80-98% bandwidth cost reduction |
| **RAG / CAG** | Bedrock_RAG | Dual generation strategies with prompt caching for cost optimization |
| **Serverless** | AnamolyDetector, Bedrock_RAG, E2E Deployment | Lambda, ECS Fargate, API Gateway — zero server management |
| **App-of-Apps** | 3Tier_EKS | ArgoCD parent application managing multiple child applications |
| **External Secrets** | 3Tier_EKS | AWS Secrets Manager → K8s Secrets via ESO (no secrets in Git) |
| **OIDC Federation** | Java_DevSecOps | GitHub Actions → AWS STS — keyless, credential-free CI/CD |

---

## 📚 Documents & Technical Guides

The [`Documents/`](./Documents/) directory contains comprehensive technical interview preparation guides and architecture references covering:

- **Cloud/DevOps Architect** — AWS architecture, EKS operations, CI/CD, Terraform
- **Integration Architect** — API design, event-driven architectures, system integration
- **DevSecOps Architect** — Security scanning, compliance automation, supply chain security
- **SRE/Platform Engineer** — Observability, incident response, platform engineering
- **Solution Architect** — Well-Architected Framework, cost optimization, migration strategies
- **EKS Upgrade Guides** — Detailed EKS 1.29 → 1.31 upgrade procedures (3 parts)
- **Enterprise Architecture** — EA thinking frameworks and principal architect patterns
- **Data Engineering** — GCP ecosystem: Kafka, Apache Beam, Airflow, Kubernetes

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
| `kubectl` | EKS projects (3Tier_EKS, EKS_DevSecOPs, Java_DevSecOps) |
| `helm` | EKS projects with Helm charts |
| `docker` | All container-based projects |
| `node` (v20+) | React frontend projects |
| `python` (3.11+) | Lambda functions, AI agents |

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
- ✅ **Encryption in transit** — TLS 1.2+ for all inter-service communication
- ✅ **Least-privilege IAM** — Scoped IAM roles per function/service
- ✅ **Private networking** — Private subnets, VPC Endpoints, no public IPs on compute
- ✅ **Security scanning** — SAST (SonarCloud), SCA (OWASP DC), container scanning (Trivy), IaC scanning (Checkov)
- ✅ **Audit logging** — CloudTrail, VPC Flow Logs, CloudWatch Logs
- ✅ **Threat detection** — GuardDuty, Security Hub, AWS Config rules

---

## 💰 Cost Awareness

Each project includes cost estimates and optimization strategies:

| Project | Estimated Monthly Cost | Key Optimization |
|---------|----------------------|-----------------|
| AnamolyDetector | ~$1–$2 | Free-tier Lambda, PAY_PER_REQUEST DynamoDB |
| IOT_LemonGrass | ~$5 (edge) | Edge aggregation saves ~$304/month vs raw ingestion |
| Bedrock_RAG | ~$60 (dev) | VPC Endpoints over NAT GW, CAG prompt caching |
| Java_DevSecOps | ~$235 | No Jenkins/SonarQube EC2 (saves ~$100) |
| 3Tier_EKS | Variable | Karpenter spot instances, RDS reserved instances |
| E2E Deployment | ~$30–$50 | Fargate pay-per-use, automated cleanup workflow |

---

## 📄 License

MIT License — Pushparaj Naik

All projects are available for educational, demonstration, and professional portfolio purposes. Feel free to fork, modify, and learn from them.

---

**Built with precision by Pushparaj Naik** | [GitHub](https://github.com/pusnaik2016)