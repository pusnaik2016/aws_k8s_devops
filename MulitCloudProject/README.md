# 🏗️ Global Multicloud Healthcare & Financial Transaction Clearing Engine

**Production-grade multicloud infrastructure** for ingesting, validating, and clearing sensitive medical billing transactions across AWS, Azure, and GCP.

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.7.0-623CE4?logo=terraform)](https://terraform.io)
[![AWS](https://img.shields.io/badge/AWS-Primary%20Active-FF9900?logo=amazon-aws)](https://aws.amazon.com)
[![Azure](https://img.shields.io/badge/Azure-Hot%20Standby-0078D4?logo=microsoft-azure)](https://azure.microsoft.com)
[![GCP](https://img.shields.io/badge/GCP-Compliance-4285F4?logo=google-cloud)](https://cloud.google.com)
[![Compliance](https://img.shields.io/badge/HIPAA%20|%20SOX%20|%20GDPR%20|%20PCI--DSS-Compliant-00C853)]()

---

## 📋 Table of Contents

- [Architecture Overview](#-architecture-overview)
- [Application Architecture](#-application-architecture)
- [High-Level Topology](#-high-level-topology)
- [Component Matrix](#-component-matrix)
- [Network Architecture](#-network-architecture)
- [Data Flow Architecture](#-data-flow-architecture)
- [Compliance Architecture](#-compliance-architecture)
- [Identity Architecture (Azure AD)](#-identity-architecture-azure-ad)
- [Directory Structure](#-directory-structure)
- [Prerequisites](#-prerequisites)
- [Deployment Guide](#-deployment-guide)
- [GitOps & ArgoCD](#-gitops--argocd)
- [Disaster Recovery](#-disaster-recovery)

---

## 🏛️ Architecture Overview

This system implements a **three-cloud active/standby/compliance** architecture:

| Cloud | Role | Services |
|-------|------|----------|
| **AWS** | Primary Active Site | EKS, Aurora PostgreSQL, ElastiCache Redis, CloudFront + WAF, Route 53, ECR |
| **Azure** | Hot Standby Site | AKS, Azure SQL Hyperscale, Azure Cache for Redis, Front Door + WAF, ACR |
| **GCP** | Compliance & Analytics | GKE, AlloyDB, BigQuery, Cloud Armor, Cloud KMS |

---

## 🧩 Application Architecture

### What Runs Inside the Clusters

The clearing engine is composed of **4 Python/FastAPI microservices** that run as containers inside EKS, AKS, and GKE:

```
     External Request
          │
          ▼
┌──────────────────────┐     ┌──────────────────────┐
│ transaction-         │────▶│ clearing-engine-     │
│ ingestion            │     │ core                 │
│                      │     │                      │
│ Receives, validates, │     │ Matches, validates,  │
│ and queues incoming  │     │ and settles batches  │
│ healthcare/financial │     │ of transactions      │
│ transactions         │     │                      │
│                      │     │     ┌────────┐       │
│ POST /transactions   │     │     │        │       │
│ POST /transactions/  │     │     ▼        ▼       │
│      batch           │     └─────┬────────┬───────┘
└──────────────────────┘           │        │
                            ┌──────▼──┐  ┌──▼──────────────┐
                            │ audit-  │  │ notification-   │
                            │ pipeline│  │ service         │
                            │         │  │                 │
                            │ Streams │  │ Sends status    │
                            │ events  │  │ updates via     │
                            │ to BQ,  │  │ webhooks,       │
                            │ Aurora, │  │ SQS, ASB        │
                            │ AlloyDB │  │                 │
                            └─────────┘  └─────────────────┘
```

| Service | Port | What It Does | Runs On |
|---------|------|-------------|--------|
| **transaction-ingestion** | 8000 | Receives transactions via REST, validates schemas, deduplicates via Redis, persists to DB | EKS + AKS |
| **clearing-engine-core** | 8000 | Core clearing logic — matches counterparties, validates business rules, settles batches | EKS + AKS |
| **audit-pipeline** | 8000 | Streams every transaction event to BigQuery (audit trail), AlloyDB (compliance), with PII tokenization (GDPR) | EKS + AKS + GKE |
| **notification-service** | 8000 | Sends transaction status updates via webhooks, SQS (AWS), Azure Service Bus, email | EKS + AKS |

### How Applications Are Built and Stored

```
 ┌─────────────────────────────────────────────────────────────────────────┐
 │                      CI/CD Application Pipeline                        │
 │                                                                        │
 │  Developer pushes code to src/                                         │
 │       │                                                                │
 │       ▼                                                                │
 │  ┌─────────────────────────────┐                                       │
 │  │ ci-app.yml (GitHub Actions) │                                       │
 │  │                             │                                       │
 │  │  Step 1: Lint (ruff) &      │                                       │
 │  │          Test (pytest)      │  ← Runs for all 4 services in parallel│
 │  │                             │                                       │
 │  │  Step 2: Security Scan      │                                       │
 │  │    • Trivy (container CVEs) │  ← Fails on CRITICAL/HIGH findings   │
 │  │    • TruffleHog (secrets)   │                                       │
 │  │                             │                                       │
 │  │  Step 3: Docker Build       │                                       │
 │  │    • Multi-stage Dockerfile │  ← python:3.12-slim, non-root user   │
 │  │    • Multi-arch (amd64+arm) │                                       │
 │  │    • Push to BOTH:          │                                       │
 │  │      ├── AWS ECR ──────────────── via VPC Interface Endpoints       │
 │  │      └── Azure ACR ────────────── via Private Endpoint              │
 │  └──────────────┬──────────────┘                                       │
 │                 │                                                      │
 │                 ▼                                                      │
 │  ┌─────────────────────────────┐                                       │
 │  │ cd-app.yml (GitHub Actions) │                                       │
 │  │                             │                                       │
 │  │  Step 1: Deploy to EKS      │  ← helm upgrade --install --atomic   │
 │  │    uses: values-aws.yaml    │    (IRSA, ECR registry, prod sizing) │
 │  │                             │                                       │
 │  │  Step 2: Deploy to AKS      │  ← helm upgrade --install --atomic   │
 │  │    uses: values-azure.yaml  │    (Workload ID, ACR, standby size)  │
 │  │                             │                                       │
 │  │  Step 3: Deploy to GKE      │  ← helm upgrade --install --atomic   │
 │  │    uses: values-gcp.yaml    │    (audit-pipeline ONLY)             │
 │  └─────────────────────────────┘                                       │
 └─────────────────────────────────────────────────────────────────────────┘
```

### Container Registries (Private Access Only)

Both EKS and AKS are **private clusters** with no Internet Gateway or NAT. Image pulls happen entirely within the private network:

| Registry | Cloud | Access Method | Key Features |
|----------|-------|---------------|-------------|
| **ECR** (Elastic Container Registry) | AWS | VPC Interface Endpoints (`ecr.api`, `ecr.dkr`, `s3`) | KMS encryption, scan-on-push, immutable tags, 30-image retention |
| **ACR** (Azure Container Registry) | Azure | Private Endpoint + Private DNS Zone (`privatelink.azurecr.io`) | Premium SKU, content trust, quarantine policy, AcrPull via managed identity |

### Helm Chart Structure

Applications are deployed using a **Helm umbrella chart** with 4 subcharts:

```
helm/clearing-engine/
├── Chart.yaml               # Umbrella chart (4 subchart dependencies)
├── values.yaml              # Base: replicas, resources, HPA, PDB
├── values-aws.yaml          # EKS: ECR images, IRSA annotations, prod sizing
├── values-azure.yaml        # AKS: ACR images, Workload Identity, standby sizing
├── values-gcp.yaml          # GKE: audit-pipeline ONLY, GCP Workload Identity
├── templates/
│   └── network-policies.yaml  # Zero-trust pod-to-pod rules
└── charts/
    ├── transaction-ingestion/  # Deployment, Service, HPA, PDB, ServiceAccount
    ├── clearing-engine-core/
    ├── audit-pipeline/
    └── notification-service/
```

Each subchart Deployment includes:
- **Security Context**: `runAsNonRoot`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation: false`
- **Probes**: Liveness (`/health`), Readiness (`/ready`)
- **HPA**: Auto-scale at 70% CPU (3–15 replicas for ingestion, 3–20 for clearing)
- **PDB**: `minAvailable: 2` for zero-downtime upgrades
- **NetworkPolicies**: Only allowed paths: `ingestion → clearing → audit/notification`

---

## 🌐 High-Level Topology

```
                              ┌─────────────────────────────────────────┐
                              │         GLOBAL TRAFFIC LAYER            │
                              │   Route 53 (Latency-Based + Failover)   │
                              └──────────────────┬──────────────────────┘
                                                 │
                    ┌────────────────────────────┴────────────────────────────┐
                    │                                                        │
                    ▼                                                        ▼
    ┌───────────────────────────────────┐          ┌───────────────────────────────────┐
    │      PRIMARY: AWS (us-east-1)     │          │    HOT STANDBY: AZURE (eastus)    │
    │                                   │          │                                   │
    │  ┌─────────────────────────────┐  │          │  ┌─────────────────────────────┐  │
    │  │ CloudFront + AWS WAF        │  │          │  │ Front Door + Azure WAF      │  │
    │  │  ├── OWASP Managed Rules    │  │          │  │  ├── Bot Protection         │  │
    │  │  ├── Rate Limiting          │  │          │  │  ├── OWASP 3.2 Ruleset      │  │
    │  │  └── Geo-Restriction (GDPR) │  │          │  │  └── Geo-Filtering (GDPR)   │  │
    │  └────────────┬────────────────┘  │          │  └────────────┬────────────────┘  │
    │               │                   │          │               │                   │
    │  ┌────────────▼────────────────┐  │          │  ┌────────────▼────────────────┐  │
    │  │ Application Load Balancer   │  │          │  │ Application Gateway         │  │
    │  └────────────┬────────────────┘  │          │  └────────────┬────────────────┘  │
    │               │                   │          │               │                   │
    │  ┌────────────▼────────────────┐  │          │  ┌────────────▼────────────────┐  │
    │  │ EKS Cluster (v1.30)        │  │          │  │ AKS Cluster (v1.30)        │  │
    │  │  ├── Istio (STRICT mTLS)   │  │          │  │  ├── Istio (STRICT mTLS)   │  │
    │  │  ├── ArgoCD (GitOps)       │  │          │  │  ├── ArgoCD (GitOps)       │  │
    │  │  ├── IRSA (Pod IAM)        │  │          │  │  ├── Azure AD RBAC         │  │
    │  │  └── Private Endpoints     │  │          │  │  └── Workload Identity     │  │
    │  └────────────┬────────────────┘  │          │  └────────────┬────────────────┘  │
    │               │                   │          │               │                   │
    │  ┌────────────▼────────────────┐  │          │  ┌────────────▼────────────────┐  │
    │  │ ElastiCache Redis 7.x      │  │          │  │ Azure Cache for Redis      │  │
    │  │  └── 3 Shards × 2 Replicas │  │          │  │  └── Premium P1 (3 shards) │  │
    │  └────────────┬────────────────┘  │          │  └────────────┬────────────────┘  │
    │               │                   │          │               │                   │
    │  ┌────────────▼────────────────┐  │          │  ┌────────────▼────────────────┐  │
    │  │ Aurora PostgreSQL 15.x     │  │  Storage  │  │ Azure SQL Hyperscale       │  │
    │  │  ├── Global Database       │──┼───Sync───►│  │  ├── 2 HA Replicas         │  │
    │  │  ├── Writer + Reader       │  │          │  │  ├── Azure AD Auth          │  │
    │  │  ├── CMK Encryption        │  │          │  │  ├── TDE (CMK)              │  │
    │  │  └── pgAudit + Perf Insight│  │          │  │  └── 7-Year Retention       │  │
    │  └─────────────────────────────┘  │          │  └─────────────────────────────┘  │
    └───────────────┬───────────────────┘          └───────────────┬───────────────────┘
                    │                                              │
                    │         ┌──────────────────────────┐         │
                    │         │   IPSec VPN Mesh (IKEv2)  │         │
                    └────────►│   AES-256-GCM + SHA-384   │◄────────┘
                              │   BGP Dynamic Routing     │
                              └────────────┬──────────────┘
                                           │
                              ┌────────────▼──────────────────────────────┐
                              │      COMPLIANCE LAYER: GCP (us-central1) │
                              │                                          │
                              │  ┌────────────────────────────────────┐   │
                              │  │ Cloud DNS → Cloud Armor WAF       │   │
                              │  └──────────────┬─────────────────────┘   │
                              │                 │                        │
                              │  ┌──────────────▼─────────────────────┐   │
                              │  │ GKE Cluster (Analytics Pods)      │   │
                              │  │  ├── Workload Identity            │   │
                              │  │  ├── Binary Authorization         │   │
                              │  │  ├── Shielded Nodes               │   │
                              │  │  └── Managed Prometheus           │   │
                              │  └──────────────┬─────────────────────┘   │
                              │                 │                        │
                              │  ┌──────────────▼─────────────────────┐   │
                              │  │ AlloyDB Omni (Compliance Audits)  │   │
                              │  │  ├── CMEK Encryption              │   │
                              │  │  ├── pgAudit (All Statements)     │   │
                              │  │  └── Read Pool (2 nodes)          │   │
                              │  └──────────────┬─────────────────────┘   │
                              │                 │                        │
                              │  ┌──────────────▼─────────────────────┐   │
                              │  │ BigQuery                          │   │
                              │  │  ├── US: compliance_audit_logs    │   │
                              │  │  │   ├── transaction_audit_trail  │   │
                              │  │  │   ├── pii_access_log           │   │
                              │  │  │   └── config_drift_events      │   │
                              │  │  └── EU: anonymized_gdpr_data     │   │
                              │  └────────────────────────────────────┘   │
                              └──────────────────────────────────────────┘
```

---

## 🔧 Component Matrix

| Component | AWS (Primary) | Azure (Hot Standby) | GCP (Compliance) |
|-----------|---------------|---------------------|------------------|
| **Global DNS** | Route 53 | Azure DNS | Cloud DNS |
| **CDN & Edge** | CloudFront + WAF | Front Door Premium + WAF | Cloud CDN + Armor |
| **Compute** | EKS + Managed Nodes | AKS + System/User Pools | GKE Standard |
| **Service Mesh** | Istio (STRICT mTLS) | Istio (STRICT mTLS) | Istio (STRICT mTLS) |
| **GitOps** | ArgoCD | ArgoCD | ArgoCD |
| **Database** | Aurora PostgreSQL 15 | SQL Hyperscale | AlloyDB PostgreSQL |
| **Caching** | ElastiCache Redis 7.x | Cache for Redis Premium | — |
| **Analytics** | — | — | BigQuery |
| **Secrets** | KMS + IRSA | Key Vault + Workload ID | Cloud KMS + WI |
| **VPN** | VPN Gateway (BGP 65000) | VPN Gateway (BGP 65001) | HA VPN (BGP 65002) |
| **Compliance** | CloudTrail + Config | Azure Policy + Defender | Audit Logs + SCC |
| **Identity** | IAM + OIDC | **Azure AD (Central)** | IAM + WI Pools |

---

## 🔐 Network Architecture

### Cross-Cloud VPN Mesh

```
    AWS (10.0.0.0/16)                Azure (10.1.0.0/16)
    ASN: 65000                       ASN: 65001
         │                                │
         ├── IPSec Tunnel 1 ──────────────┤
         ├── IPSec Tunnel 2 (redundant) ──┤
         │                                │
         │         GCP (10.2.0.0/16)      │
         │            ASN: 65002          │
         │                │               │
         ├── Tunnel A ────┤               │
         ├── Tunnel B ────┤               │
         │                ├── Tunnel C ───┤
         │                └── Tunnel D ───┘

    All tunnels: IKEv2, AES-256-GCM, SHA-384, DH Group 20
```

### Subnet Architecture

| Cloud | Subnet | CIDR | Purpose |
|-------|--------|------|---------|
| AWS | Public (×2) | 10.0.0.0/24, 10.0.1.0/24 | ALB, NAT Gateways |
| AWS | Private-App (×2) | 10.0.10.0/24, 10.0.11.0/24 | EKS Worker Nodes |
| AWS | Private-Data (×2) | 10.0.20.0/24, 10.0.21.0/24 | Aurora, ElastiCache |
| Azure | AKS System | 10.1.0.0/24 | AKS System Pool |
| Azure | AKS User | 10.1.1.0/24 | AKS User Pool |
| Azure | Data | 10.1.10.0/24 | SQL, Redis, Key Vault |
| Azure | Gateway | 10.1.255.0/24 | VPN Gateway |
| GCP | GKE Nodes | 10.2.0.0/20 | GKE Node Pool |
| GCP | Data | 10.2.16.0/20 | AlloyDB, Private Services |

---

## 📊 Data Flow Architecture

```
    User Request
         │
         ▼
    Route 53 (Latency Routing)
         │
    ┌────┴──── EU user? ────── GDPR Geolocation ───► EU Processing
    │
    ▼
    CloudFront → WAF → ALB → EKS Pod
                                │
                    ┌───────────┤
                    ▼           ▼
            ElastiCache    Aurora PG
            (Session)     (Transaction)
                                │
                    ┌───────────┴───────────┐
                    ▼                       ▼
            Azure SQL Hyperscale     GCP BigQuery
            (Hot Standby Sync)     (Audit Trail)
                                        │
                                ┌───────┴────────┐
                                ▼                ▼
                        AlloyDB Omni      EU BigQuery
                        (Compliance)    (GDPR Anonymized)
```

---

## 🛡️ Compliance Architecture

### HIPAA Controls

| Control | Implementation |
|---------|---------------|
| Data at Rest Encryption | AWS KMS (CMK), Azure Key Vault (CMK), GCP Cloud KMS (CMEK) |
| Data in Transit | Istio mTLS (STRICT mode) + IPSec VPN (AES-256-GCM) |
| Access Controls | IAM Roles, Azure RBAC, GCP IAM + Workload Identity |
| Audit Logging | CloudTrail, Azure Monitor, GCP Audit Logs → BigQuery |
| Network Isolation | VPC/VNet with NACLs/NSGs, private subnets, no public DB access |
| Backup & Recovery | Aurora: 35-day, Azure SQL: 7-year, AlloyDB: 35-day + PITR |

### SOX Controls

| Control | Implementation |
|---------|---------------|
| Immutable Audit Trail | CloudTrail (S3 + Glacier, 7yr), Azure Activity Log, GCP → BigQuery |
| Separation of Duties | Admin/Dev/Compliance Azure AD groups, IAM role boundaries |
| Change Detection | AWS Config Rules, Azure Policy, GCP Org Policies + Drift Alerts |
| Financial Auditability | pgAudit on all DB writes, Performance Insights, BigQuery analytics |

### GDPR Controls

| Control | Implementation |
|---------|---------------|
| Data Sovereignty | Route 53 geolocation routing, BigQuery EU dataset, KMS EU keyring |
| Right to Erasure | Tokenized PII, anonymization in microservices before cross-cloud sync |
| Egress Control | Istio Sidecar REGISTRY_ONLY mode + whitelisted ServiceEntries |
| Data Minimization | Pod-level egress blocks unauthorized API calls |

---

## 👤 Identity Architecture (Azure AD)

Azure Active Directory serves as the **centralized identity provider** across all three clouds:

```
                     ┌─────────────────────────────────┐
                     │        Azure Active Directory    │
                     │                                  │
                     │  ┌──────────────────────────┐    │
                     │  │  MultiCloud-Platform-     │    │
                     │  │  Admins                   │────┼──► AKS Admin, Key Vault Admin
                     │  └──────────────────────────┘    │     Contributor Role
                     │                                  │
                     │  ┌──────────────────────────┐    │
                     │  │  MultiCloud-Developers    │────┼──► AKS User, KV Secrets User
                     │  └──────────────────────────┘    │
                     │                                  │
                     │  ┌──────────────────────────┐    │
                     │  │  MultiCloud-Compliance-   │────┼──► Reader, Log Analytics Reader
                     │  │  Auditors                 │    │
                     │  └──────────────────────────┘    │
                     │                                  │
                     │  ┌──────────────────────────┐    │
                     │  │  GitHub Actions OIDC SP   │────┼──► Contributor (CI/CD)
                     │  └──────────────────────────┘    │
                     └─────────────────────────────────┘
```

---

## 📁 Directory Structure

```
MulitCloudProject/
├── .github/workflows/
│   ├── aws-deploy.yml           # Infra: AWS DevSecOps pipeline (Terraform)
│   ├── azure-deploy.yml         # Infra: Azure DevSecOps pipeline (Terraform)
│   ├── gcp-deploy.yml           # Infra: GCP DevSecOps pipeline (Terraform)
│   ├── ci-app.yml               # App: Build, test, scan, push to ECR+ACR
│   └── cd-app.yml               # App: Deploy Helm chart to EKS→AKS→GKE
├── src/                          # Application microservices (Python/FastAPI)
│   ├── transaction-ingestion/    # Receives & validates transactions
│   │   ├── Dockerfile            #   Multi-stage, non-root, python:3.12-slim
│   │   ├── requirements.txt      #   FastAPI, asyncpg, redis, structlog
│   │   ├── app/
│   │   │   ├── main.py            #   FastAPI entry point + Prometheus metrics
│   │   │   ├── config.py          #   Pydantic Settings (env-driven, no secrets)
│   │   │   ├── routes/
│   │   │   │   ├── health.py      #   /health (liveness), /ready (readiness)
│   │   │   │   └── transactions.py #  POST /api/v1/transactions
│   │   │   ├── models/            #   Pydantic request/response schemas
│   │   │   └── services/          #   DB, Redis, validation logic
│   │   └── tests/                 #   pytest unit tests
│   ├── clearing-engine/          # Core clearing & settlement logic
│   ├── audit-pipeline/           # Compliance event streaming (→ BigQuery)
│   └── notification-service/     # Webhooks, SQS, Azure Service Bus
├── helm/                          # Kubernetes deployment (Helm v3)
│   └── clearing-engine/           # Umbrella chart
│       ├── Chart.yaml             #   4 subchart dependencies
│       ├── values.yaml            #   Base: resources, HPA, PDB
│       ├── values-aws.yaml        #   EKS: ECR images, IRSA annotations
│       ├── values-azure.yaml      #   AKS: ACR images, Workload Identity
│       ├── values-gcp.yaml        #   GKE: audit-pipeline only
│       ├── templates/
│       │   └── network-policies.yaml  # Zero-trust pod-to-pod rules
│       └── charts/                #   Per-service subcharts
│           ├── transaction-ingestion/  # Deployment, Service, HPA, PDB, SA
│           ├── clearing-engine-core/
│           ├── audit-pipeline/
│           └── notification-service/
├── terraform/                     # Infrastructure as Code
│   ├── bootstrap/                 # State backend provisioning (run once)
│   │   ├── main.tf                #   S3+DynamoDB, Azure Storage, GCS
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── providers.tf
│   ├── modules/
│   │   ├── aws_infra/             # 15 files: VPC, EKS, Aurora, ECR, VPC Endpoints...
│   │   ├── azure_infra/           # 13 files: VNet, AKS, SQL, ACR, Private Endpoints...
│   │   └── gcp_infra/             # 10 files: VPC, GKE, AlloyDB, BigQuery...
│   └── environments/
│       └── production/            # Root module: wires all 3 cloud modules
├── gitops/                        # ArgoCD + Istio service mesh config
│   └── apps/
│       ├── base/                  #   Namespace + Istio STRICT mTLS
│       ├── aws/                   #   ArgoCD app + Istio egress for EKS
│       ├── azure/                 #   ArgoCD app + Istio egress for AKS
│       └── gcp/                   #   ArgoCD app + Istio egress for GKE
├── docs/
│   └── RUNBOOK.md                 # Operations Runbook (650+ lines)
└── README.md
```

---

## ✅ Prerequisites

1. **Cloud Accounts**: Active AWS, Azure, and GCP accounts with billing enabled
2. **Terraform**: >= 1.7.0 installed locally
3. **Helm**: >= 3.15.0 installed locally
4. **Python**: >= 3.12 (for local development/testing)
5. **Docker**: For building container images locally
6. **OIDC Federation** (for CI/CD):
   - AWS: IAM OIDC Identity Provider + IAM Role for GitHub Actions
   - Azure: App Registration + Federated Credentials
   - GCP: Workload Identity Pool + Provider
7. **DNS Domain**: A registered domain for Route 53 hosted zone
8. **GitHub Secrets**: Configure all required secrets (see below)

### Required GitHub Secrets

| Secret | Purpose |
|--------|---------|
| `AWS_ROLE_ARN` | OIDC role for AWS authentication |
| `AZURE_CLIENT_ID` / `AZURE_TENANT_ID` / `AZURE_SUBSCRIPTION_ID` | Azure OIDC |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` / `GCP_SERVICE_ACCOUNT` | GCP OIDC |
| `ACR_NAME` / `ACR_LOGIN_SERVER` | Azure Container Registry |
| `EKS_CLUSTER_NAME` / `AKS_CLUSTER_NAME` / `GKE_CLUSTER_NAME` | Cluster names |
| `AURORA_WRITER_ENDPOINT` / `AZURE_SQL_ENDPOINT` / `ALLOYDB_PRIVATE_IP` | DB endpoints |
| `ELASTICACHE_ENDPOINT` / `AZURE_REDIS_ENDPOINT` | Cache endpoints |
| `VPN_PSK_AWS_AZURE` / `VPN_PSK_AWS_GCP` / `VPN_PSK_AZURE_GCP` | VPN pre-shared keys |

---

## 🚀 Deployment Guide

Deployment happens in 3 phases: **Bootstrap → Infrastructure → Application**.

### Phase 1: Bootstrap State Backends (One-time)

```bash
cd terraform/bootstrap
terraform init
terraform apply
# Note the output — copy S3/DynamoDB names into environments/production/providers.tf
```

### Phase 2: Provision Infrastructure

```bash
cd terraform/environments/production
vim terraform.tfvars          # Set your actual values
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

This provisions across all 3 clouds:
- VPCs/VNets, subnets, security groups
- EKS, AKS, GKE clusters (private, no public endpoints)
- Aurora, Azure SQL, AlloyDB databases
- ElastiCache, Azure Redis
- ECR (+ 9 VPC endpoints), ACR (+ Private Endpoint)
- Cross-cloud VPN mesh (6 tunnels)

### Phase 3: Build and Deploy Applications

#### Option A: Via CI/CD (Recommended)

Push code to `main` — the pipelines handle everything:

```
src/ change → ci-app.yml runs:
  ├── Lint + Test (all 4 services in parallel)
  ├── Trivy container scan
  └── Build + Push to ECR and ACR

ci-app.yml success → cd-app.yml runs:
  ├── helm upgrade → EKS (primary, all services)
  ├── helm upgrade → AKS (standby, all services)
  └── helm upgrade → GKE (audit-pipeline only)
```

#### Option B: Manual Local Deploy

```bash
# 1. Build images locally
for svc in transaction-ingestion clearing-engine audit-pipeline notification-service; do
  docker build -t $svc:latest src/$svc/
done

# 2. Tag and push to ECR
aws ecr get-login-password | docker login --username AWS --password-stdin <ECR_REGISTRY>
for svc in transaction-ingestion clearing-engine audit-pipeline notification-service; do
  docker tag $svc:latest <ECR_REGISTRY>/multicloud-clearing-engine/$svc:latest
  docker push <ECR_REGISTRY>/multicloud-clearing-engine/$svc:latest
done

# 3. Deploy to EKS via Helm
aws eks update-kubeconfig --name <CLUSTER_NAME>
helm upgrade --install clearing-engine helm/clearing-engine/ \
  --namespace clearing-engine --create-namespace \
  -f helm/clearing-engine/values.yaml \
  -f helm/clearing-engine/values-aws.yaml \
  --set global.imageRegistry=<ECR_REGISTRY> \
  --wait --atomic

# 4. Verify
kubectl get pods -n clearing-engine
kubectl logs deploy/transaction-ingestion -n clearing-engine
```

### Phase 4: Configure ArgoCD & GitOps

```bash
# On each cluster:
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Apply mesh and GitOps config
kubectl apply -f gitops/apps/base/     # Namespace + Istio mTLS
kubectl apply -f gitops/apps/<cloud>/  # ArgoCD app + egress rules
```

---

## 🔄 GitOps & ArgoCD

ArgoCD manages the Kubernetes state after Terraform provisions infrastructure:

- **Auto-sync**: Changes pushed to `gitops/apps/` are automatically applied
- **Self-heal**: Manual cluster changes are reverted to Git state
- **Prune**: Orphaned resources are automatically cleaned up

---

## 🔥 Disaster Recovery

| Scenario | RTO | RPO | Procedure |
|----------|-----|-----|-----------|
| AWS Region Failure | 5 min | 0 (sync replication) | Route 53 auto-failover to Azure |
| Single AZ Failure | 0 | 0 | Multi-AZ architecture handles automatically |
| Database Corruption | 30 min | 5 min (PITR) | Point-in-time recovery from Aurora |
| Full Cloud Outage | 15 min | ~1 min | Manual DNS cutover to Azure Front Door |

---

## 📊 CI/CD Pipeline Summary

| Pipeline | File | Trigger | What It Does |
|----------|------|---------|-------------|
| **AWS Infra** | `aws-deploy.yml` | `terraform/**` changes | Checkov → Plan → Apply → ArgoCD sync |
| **Azure Infra** | `azure-deploy.yml` | `terraform/modules/azure_infra/**` | Checkov+tfsec → Plan → Apply → Compliance report |
| **GCP Infra** | `gcp-deploy.yml` | `terraform/modules/gcp_infra/**` | Checkov+tfsec → Plan → Apply → Compliance report |
| **App CI** | `ci-app.yml` | `src/**` changes | Lint → Test → Trivy → Build+Push to ECR+ACR |
| **App CD** | `cd-app.yml` | After CI success | Helm deploy → EKS → AKS → GKE |

See [docs/RUNBOOK.md](docs/RUNBOOK.md) for detailed operational procedures.
