# MedCloud Global — Architecture Document

## 1. System Context

MedCloud Global is a multi-cloud healthcare and medical e-commerce platform that serves patients, healthcare providers, and pharmacies across multiple geographic regions. The system handles Protected Health Information (PHI), Personally Identifiable Information (PII), and payment card data, requiring simultaneous compliance with **HIPAA**, **GDPR**, and **PCI-DSS**.

---

## 2. Architecture Decision Records (ADRs)

### ADR-001: Multi-Cloud Provider Selection

**Decision:** Assign distinct strategic roles to each cloud provider.

| Cloud | Role | Rationale |
|-------|------|-----------|
| **AWS** | Core E-Commerce & Compute Hub | Broadest service catalog, mature EKS, global Aurora database, best CDN (CloudFront) |
| **Azure** | Enterprise Medical & AI Hub | Azure OpenAI (exclusive GPT-4 access), best SQL Server/AD integration, Cosmos DB for global patient data |
| **GCP** | Big Data & ML Analytics Engine | BigQuery (serverless analytics), Vertex AI (ML ops), Cloud DLP (PHI scrubbing), strongest data platform |

### ADR-002: Kubernetes as Universal Compute

**Decision:** Run all application workloads on Kubernetes (EKS/AKS/GKE) with Istio service mesh.

**Rationale:** Kubernetes provides a consistent API across all three clouds, enabling portable deployments, unified observability, and cross-cloud service communication via Istio mTLS.

### ADR-003: Data Residency & Sovereignty

**Decision:** PHI data stays in the originating cloud. Only anonymized/de-identified data crosses cloud boundaries.

**Rationale:** HIPAA requires PHI to remain within controlled environments. Cross-cloud data transfer uses GCP Cloud DLP for de-identification before analytics.

---

## 3. High-Level Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         GLOBAL EDGE LAYER                                    │
│                                                                              │
│  ┌────────────┐    ┌────────────────┐    ┌──────────────┐                  │
│  │ Route 53   │    │ CloudFront     │    │ Azure Front  │                  │
│  │ (DNS)      │───▶│ (CDN + WAF)    │    │ Door (CDN)   │                  │
│  │ Latency    │    │ + AWS WAF      │    │ + WAF        │                  │
│  │ Routing    │    │ + Shield Adv   │    │              │                  │
│  └────────────┘    └───────┬────────┘    └──────┬───────┘                  │
│                            │                     │                          │
└────────────────────────────┼─────────────────────┼──────────────────────────┘
                             │                     │
┌────────────────────────────┼─────────────────────┼──────────────────────────┐
│                    CROSS-CLOUD MESH (Istio mTLS)                             │
│                                                                              │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐          │
│  │   AWS (EKS)       │  │   Azure (AKS)    │  │   GCP (GKE)      │          │
│  │                    │  │                  │  │                  │          │
│  │ ┌──────────────┐  │  │ ┌──────────────┐ │  │ ┌──────────────┐ │         │
│  │ │Storefront API│  │  │ │Patient Svc   │ │  │ │AI Gateway    │ │         │
│  │ │(e-commerce)  │──┼──┼▶│(healthcare)  │ │  │ │(ML/analytics)│ │         │
│  │ └──────────────┘  │  │ └──────────────┘ │  │ └──────────────┘ │         │
│  │ ┌──────────────┐  │  │ ┌──────────────┐ │  │                  │         │
│  │ │Order Service │──┼──┼▶│Imaging Svc   │ │  │                  │         │
│  │ │(transactions)│  │  │ │(DICOM/AI)    │─┼──┼▶ Vertex AI       │         │
│  │ └──────────────┘  │  │ └──────────────┘ │  │  BigQuery        │         │
│  │ ┌──────────────┐  │  │                  │  │  Cloud DLP       │         │
│  │ │Notification  │  │  │                  │  │                  │         │
│  │ │Service       │  │  │                  │  │                  │         │
│  │ └──────────────┘  │  │                  │  │                  │         │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘          │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
                             │                     │                 │
┌────────────────────────────┼─────────────────────┼─────────────────┼────────┐
│                        DATA LAYER                                            │
│                                                                              │
│  AWS                       │  Azure               │  GCP                    │
│  ┌──────────────────┐      │  ┌────────────────┐  │  ┌────────────────┐    │
│  │Aurora Global DB  │      │  │Cosmos DB       │  │  │BigQuery        │    │
│  │(PostgreSQL)      │      │  │(MongoDB API)   │  │  │(analytics)     │    │
│  │Orders, Products  │      │  │Patient Profiles│  │  │Cross-cloud     │    │
│  └──────────────────┘      │  └────────────────┘  │  │telemetry       │    │
│  ┌──────────────────┐      │  ┌────────────────┐  │  └────────────────┘    │
│  │DynamoDB          │      │  │Blob Storage    │  │  ┌────────────────┐    │
│  │Sessions, Carts   │      │  │DICOM images    │  │  │Cloud Storage   │    │
│  └──────────────────┘      │  │EHR documents   │  │  │Data Lake       │    │
│  ┌──────────────────┐      │  └────────────────┘  │  └────────────────┘    │
│  │ElastiCache Redis │      │  ┌────────────────┐  │  ┌────────────────┐    │
│  │Caching           │      │  │Azure OpenAI    │  │  │Vertex AI       │    │
│  └──────────────────┘      │  │Clinical NLP    │  │  │Feature Store   │    │
│  ┌──────────────────┐      │  │AI Vision       │  │  │Fraud Detection │    │
│  │S3                │      │  │AI Search (RAG) │  │  │Recommendations │    │
│  │Static assets     │      │  └────────────────┘  │  └────────────────┘    │
│  └──────────────────┘      │                      │                         │
└────────────────────────────┴──────────────────────┴─────────────────────────┘
```

---

## 4. Cross-Cloud Network Topology

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     CROSS-CLOUD NETWORK ARCHITECTURE                         │
│                                                                              │
│   AWS VPC (10.0.0.0/16)         Azure VNet (10.1.0.0/16)                   │
│   ┌──────────────────┐          ┌──────────────────┐                        │
│   │  Transit Gateway │◄────────▶│  VPN Gateway     │                        │
│   │                  │ IPSec    │                  │                         │
│   │  Public Subnets  │ VPN     │  Firewall Subnet │                         │
│   │  10.0.1-3.0/24  │ Tunnel   │  10.1.0.0/26    │                         │
│   │                  │          │                  │                         │
│   │  Private Subnets │          │  AKS Subnet      │                        │
│   │  10.0.10-12.0/24│          │  10.1.1.0/24     │                        │
│   │  (EKS Nodes)     │          │                  │                        │
│   │                  │          │  Database Subnet  │                        │
│   │  Isolated Subnets│          │  10.1.2.0/24     │                        │
│   │  10.0.20-22.0/24│          │                  │                        │
│   │  (Aurora, Redis) │          │  Private Endpoints│                       │
│   └──────┬───────────┘          │  10.1.4.0/24     │                       │
│          │                      └──────┬───────────┘                        │
│          │                             │                                     │
│          │    GCP VPC (10.2.0.0/16)    │                                    │
│          │    ┌──────────────────┐      │                                   │
│          └───▶│  HA VPN Gateway  │◄─────┘                                  │
│               │  Cloud Router    │                                          │
│               │  (BGP ASN 65534) │                                          │
│               │                  │                                          │
│               │  GKE Subnet      │                                          │
│               │  10.2.1.0/24     │                                          │
│               │  Pods: 10.100/16 │                                          │
│               │  Svcs: 10.101/20 │                                          │
│               │                  │                                          │
│               │  Analytics Subnet│                                          │
│               │  10.2.3.0/24     │                                          │
│               └──────────────────┘                                          │
│                                                                              │
│   ROUTING:                                                                   │
│   • AWS ↔ Azure: Transit Gateway ↔ VPN Gateway (IPSec + BGP)              │
│   • AWS ↔ GCP:   Transit Gateway ↔ HA VPN (IPSec + BGP)                   │
│   • Azure ↔ GCP: VPN Gateway ↔ HA VPN (IPSec + BGP)                      │
│   • All tunnels: AES-256 encryption, IKEv2, PFS                            │
│   • Latency: ~10-20ms between clouds (same continent)                      │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Data Flow Architecture

```
DATA FLOW — COMPLIANCE BOUNDARIES:

┌─────────────────────────────────────────────────────────────────────────┐
│                                                                          │
│  CUSTOMER → CloudFront/WAF → ALB → Storefront API (AWS EKS)            │
│                                        │                                 │
│                    ┌───────────────────┼───────────────────┐            │
│                    │                   │                   │             │
│                    ▼                   ▼                   ▼             │
│              Order Service      Patient Service     AI Gateway          │
│              (AWS EKS)          (Azure AKS)         (GCP GKE)          │
│                    │                   │                   │             │
│                    ▼                   ▼                   ▼             │
│              Aurora DB          Cosmos DB           BigQuery            │
│              (PCI Data)         (PHI Data)          (Anonymized)        │
│                                                                          │
│  ═══════════════════════════════════════════════════════════════════    │
│  DATA CLASSIFICATION:                                                   │
│                                                                          │
│  🔴 PHI (Protected Health Information):                                 │
│     → Stays in Azure (Cosmos DB, Blob Storage)                          │
│     → Encrypted with CMK (Azure Key Vault)                              │
│     → Access logged in Azure Audit Logs                                 │
│                                                                          │
│  🟡 PCI (Payment Card Industry Data):                                   │
│     → Stays in AWS (Aurora, DynamoDB)                                   │
│     → Tokenized before cross-cloud transfer                            │
│     → Encrypted with CMK (AWS KMS)                                     │
│                                                                          │
│  🟢 Analytics (De-identified/Anonymized):                               │
│     → Flows to GCP BigQuery via Cloud DLP pipeline                     │
│     → All PII/PHI stripped by DLP templates                             │
│     → Used for ML training (fraud, recommendations)                    │
│                                                                          │
│  DATA CROSSING CLOUD BOUNDARIES:                                        │
│     Azure → GCP: PHI de-identified via Cloud DLP → BigQuery            │
│     AWS → GCP:   PCI tokenized → BigQuery for analytics                │
│     AWS ↔ Azure: mTLS via Istio mesh (no data at rest crosses)         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 6. Security Architecture

### 6.1 Defense-in-Depth Layers

| Layer | AWS | Azure | GCP |
|-------|-----|-------|-----|
| **Edge/DDoS** | CloudFront + Shield Advanced | Front Door + DDoS Protection | Cloud CDN + Cloud Armor |
| **WAF** | AWS WAF v2 (OWASP, SQLi, rate-limit) | Azure WAF on App Gateway | Cloud Armor WAF |
| **Network** | VPC + SGs + NACLs | VNet + NSGs + Azure Firewall | VPC + Firewall Rules + Cloud NGFW |
| **Identity** | IAM + IRSA | Entra ID + Workload Identity | IAM + Workload Identity |
| **Secrets** | Secrets Manager + KMS | Key Vault (HSM-backed) | Secret Manager + Cloud KMS |
| **Container** | Bottlerocket + ECR scanning | Defender for Containers | Binary Authorization + gVisor |
| **Data** | KMS CMK encryption | Key Vault CMK + Cosmos DB encryption | Cloud KMS CMK |
| **Audit** | CloudTrail + Config | Sentinel + Audit Logs | Cloud Audit Logs |
| **Threat** | GuardDuty + Security Hub | Defender for Cloud | SCC Premium |
| **Mesh** | Istio mTLS (STRICT) | Istio mTLS (STRICT) | Istio mTLS (STRICT) |

### 6.2 Zero-Trust Implementation

```
ZERO-TRUST ARCHITECTURE:

1. IDENTITY VERIFICATION (every request)
   ├── User → Entra ID / Cognito → JWT → Istio AuthorizationPolicy
   ├── Service → mTLS certificate → Istio PeerAuthentication
   └── Infrastructure → IRSA / Workload Identity / Managed Identity

2. LEAST-PRIVILEGE ACCESS
   ├── K8s RBAC (observer, developer, SRE roles)
   ├── Cloud IAM (per-service SA with minimal permissions)
   ├── Network Policies (deny-all default, explicit allow)
   └── Istio AuthorizationPolicy (per-service access control)

3. ASSUME BREACH
   ├── GuardDuty / Defender / SCC (continuous threat detection)
   ├── Sentinel SIEM (cross-cloud correlation)
   ├── Istio access logs (every request logged)
   └── Encrypted data at rest AND in transit (everywhere)

4. VERIFY EXPLICITLY
   ├── Binary Authorization (only signed images deploy)
   ├── Admission controllers (OPA Gatekeeper policies)
   ├── Container scanning (Trivy in CI/CD pipeline)
   └── Infrastructure scanning (tfsec, Checkov before apply)
```

---

## 7. Deployment Architecture

```
GITOPS DEPLOYMENT FLOW:

Developer → GitHub PR → CI Pipeline → Merge to main → ArgoCD auto-sync

┌──────────────────────────────────────────────────────────────────────┐
│  GitHub Actions CI Pipeline                                           │
│                                                                       │
│  PR Created ─▶ tfsec + Checkov ─▶ Terraform Plan ─▶ Review          │
│                                                                       │
│  Merge to main ─▶ Docker Build ─▶ Trivy Scan ─▶ Push to Registry   │
│                                                                       │
│  ArgoCD detects change ─▶ Sync ─▶ Progressive Rollout               │
│                                                                       │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐            │
│  │ AWS ECR     │     │ Azure ACR   │     │ GCP Artifact │           │
│  │ (storefront,│     │ (patient,   │     │  Registry    │           │
│  │  order,     │     │  imaging)   │     │ (ai-gateway) │           │
│  │  notification)│   │             │     │              │           │
│  └──────┬──────┘     └──────┬──────┘     └──────┬──────┘           │
│         │                    │                    │                   │
│         ▼                    ▼                    ▼                   │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐           │
│  │ ArgoCD      │     │ ArgoCD      │     │ ArgoCD      │           │
│  │ (AWS EKS)   │     │ (Azure AKS) │     │ (GCP GKE)   │          │
│  └─────────────┘     └─────────────┘     └─────────────┘           │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 8. Disaster Recovery Strategy

| Scenario | RTO | RPO | Mechanism |
|----------|-----|-----|-----------|
| **Single AZ failure** | 0 | 0 | Multi-AZ deployments (all services) |
| **Single region failure** | < 15 min | < 1 min | Aurora Global DB failover, Cosmos DB multi-region, Global LB rerouting |
| **Single cloud failure** | < 30 min | < 5 min | Istio mesh reroutes traffic, cross-cloud data replicas, DNS failover |
| **Data corruption** | < 1 hr | < 1 hr | Point-in-time recovery (Aurora 35-day, DynamoDB PITR, Cosmos DB continuous backup) |
| **Complete platform failure** | < 4 hr | < 1 hr | Full infrastructure re-provision via Terraform, data restore from backups |

---

**Document Version:** 1.0 | **Author:** Pushparaj Naik | **Classification:** Internal — Confidential
