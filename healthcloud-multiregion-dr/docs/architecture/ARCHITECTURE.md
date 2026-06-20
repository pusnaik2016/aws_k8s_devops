# HealthCloud Multi-Region DR — Architecture Document

## 1. Executive Summary

HealthCloud is a **HIPAA-compliant, multi-cloud healthcare platform** with **AWS as the primary production environment** (us-east-1) and **Azure as the disaster recovery (DR) environment** (eastus). The platform serves four core healthcare microservices — Patient, Imaging, Pharmacy, and Notification — running on Kubernetes (EKS/AKS) with a fully automated CI/CD pipeline powered by GitHub Actions and ArgoCD.

**Key Metrics:**
| Metric | Target | Current Design |
|--------|--------|----------------|
| RPO | < 15 minutes | ~10 min (async DB replication) |
| RTO | < 30 minutes | ~21 min (automated failover) |
| Availability | 99.99% | Multi-AZ + Multi-Cloud |
| Compliance | HIPAA, GDPR, SOC 2 | Full coverage |

---

## 2. System Context

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           INTERNET                                     │
│                                                                        │
│    ┌──────────┐     ┌──────────────┐     ┌───────────────────┐        │
│    │ Patients │     │ Healthcare   │     │ Insurance         │        │
│    │ & Staff  │     │ Providers    │     │ Systems (HL7/FHIR)│        │
│    └────┬─────┘     └──────┬───────┘     └────────┬──────────┘        │
│         │                  │                      │                    │
│         └──────────────────┼──────────────────────┘                    │
│                            │                                           │
│                   ┌────────▼────────┐                                  │
│                   │   Route 53      │──── Failover ────┐               │
│                   │   (DNS)         │                  │               │
│                   └────────┬────────┘                  │               │
│              ┌─────────────┴─────────────┐    ┌───────▼──────────┐    │
│              │                           │    │                  │    │
│    ┌─────────▼─────────┐     ┌───────────▼──────────────────┐    │    │
│    │  AWS us-east-1    │     │  Azure eastus                │    │    │
│    │  (PRIMARY)        │     │  (DR STANDBY)                │    │    │
│    │                   │     │                              │    │    │
│    │  CloudFront→WAF   │     │  Azure Front Door→WAF       │    │    │
│    │  ↓                │     │  ↓                          │    │    │
│    │  EKS (Istio)      │     │  AKS (Istio)               │    │    │
│    │  ↓                │     │  ↓                          │    │    │
│    │  Aurora PostgreSQL │◄────│  Azure DB PostgreSQL       │    │    │
│    │  ElastiCache Redis │     │  Azure Redis Cache         │    │    │
│    │  S3 (PHI Data)    │     │  Blob Storage (PHI Data)    │    │    │
│    └───────────────────┘     └─────────────────────────────┘    │    │
│              │                           │                      │    │
│              └───── VPN (IPSec) ─────────┘                      │    │
│                                                                  │    │
└──────────────────────────────────────────────────────────────────┘    │
```

---

## 3. Network Architecture

### 3.1 AWS VPC Design (10.0.0.0/16)

| Subnet Tier | CIDR Range | Purpose | AZs |
|-------------|-----------|---------|-----|
| Public | 10.0.0.0/20 - 10.0.32.0/20 | ALB, NAT Gateway | 3 |
| Private | 10.0.48.0/20 - 10.0.80.0/20 | EKS worker nodes, applications | 3 |
| Database | 10.0.96.0/20 - 10.0.128.0/20 | Aurora, ElastiCache (isolated) | 3 |

**Key Components:**
- **3 NAT Gateways** (prod) — one per AZ for HA
- **VPC Endpoints** — S3, ECR API, ECR DKR, STS (PrivateLink)
- **VPC Flow Logs** — all traffic to CloudWatch (HIPAA audit)
- **VPN Gateway** — IPSec tunnel to Azure VNet

### 3.2 Azure VNet Design (10.1.0.0/16)

| Subnet | CIDR Range | Purpose |
|--------|-----------|---------|
| AKS | 10.1.0.0/20 | AKS nodes and pods |
| Database | 10.1.16.0/20 | PostgreSQL Flexible (delegated) |
| Gateway | 10.1.32.0/20 | VPN Gateway |
| Private Endpoints | 10.1.48.0/20 | Key Vault, ACR, Storage PEs |

### 3.3 Cross-Cloud Connectivity

```
AWS VPC (10.0.0.0/16) ←── IPSec VPN (AES-256) ──→ Azure VNet (10.1.0.0/16)
   │                                                      │
   ├── VPN Gateway                                  VPN Gateway ──┤
   │   (aws_vpn_gateway)                      (azurerm_virtual_    │
   │                                           network_gateway)    │
   │                                                               │
   └── Customer Gateway ←── Shared Key ──→ Local Network Gateway ──┘
```

---

## 4. Compute Architecture

### 4.1 AWS EKS (Primary)

| Setting | Value |
|---------|-------|
| Version | 1.30 |
| Node Type | m6g.xlarge (Graviton ARM) |
| Node Count | 3-10 (Karpenter autoscaling) |
| Encryption | Secrets encrypted with KMS CMK |
| Logging | API, Audit, Authenticator, Controller Manager, Scheduler |
| Add-ons | VPC CNI, CoreDNS, kube-proxy, EBS CSI |
| Access | Private endpoint (prod), OIDC for IRSA |

### 4.2 Azure AKS (DR - Warm Standby)

| Setting | Value |
|---------|-------|
| Version | 1.30 |
| Node Type | Standard_D4s_v5 |
| Node Count | 2 (warm standby) → scale to 8 on failover |
| Network Policy | Calico |
| Key Vault | CSI driver with 2-min rotation |
| RBAC | Azure AD integrated |

---

## 5. Data Architecture

### 5.1 Database Layer

```
┌─────────────────────────┐           ┌─────────────────────────┐
│ Aurora PostgreSQL 16     │           │ Azure DB PostgreSQL 16   │
│ (Global Database)        │   async   │ (Flexible Server)        │
│                          │ ────────→ │                          │
│ Writer: us-east-1        │ repl lag  │ Read replica: eastus     │
│ Readers: 3 instances     │  < 15min  │ HA: ZoneRedundant        │
│ Instance: db.r6g.xlarge  │           │ Instance: GP_D4s_v3      │
│ Encryption: KMS CMK      │           │ Encryption: Key Vault    │
│ Backup: 35-day retention │           │ Backup: 35-day, GRS      │
│ PI Insights: enabled     │           │ SSL: enforced            │
└─────────────────────────┘           └─────────────────────────┘
```

### 5.2 Caching Layer

| Component | AWS (Primary) | Azure (DR) |
|-----------|---------------|------------|
| Engine | ElastiCache Redis 7.1 | Azure Cache for Redis |
| Instance | cache.r6g.large | Premium C2 |
| Cluster Mode | 3 replicas, multi-AZ | Standard with HA |
| Encryption | At-rest (KMS) + In-transit (TLS) | TLS 1.2 enforced |
| Auth | AUTH token | Access keys |

### 5.3 Storage Layer

| Bucket/Container | Purpose | Compliance |
|------------------|---------|------------|
| phi-data (S3/Blob) | Medical images, patient docs | SSE-KMS, Object Lock, 7yr retention |
| audit-logs (S3/Blob) | CloudTrail, VPC flow logs | WORM (Compliance mode), immutable |
| static-assets (S3) | Frontend assets via CloudFront | No PHI, public CDN |

---

## 6. Security Architecture

### 6.1 Defence-in-Depth Model

```
Layer 1: PERIMETER
├── AWS WAF v2 (Common Rules, SQLi, Rate Limiting)
├── Azure WAF
├── AWS Shield Advanced (DDoS)
├── CloudFront (TLS 1.2+, geo-restriction)
│
Layer 2: NETWORK
├── VPC/VNet segmentation (3-tier subnets)
├── Security Groups / NSGs (least-privilege)
├── Network Policies (default-deny, K8s)
├── Istio mTLS STRICT (service-to-service)
│
Layer 3: APPLICATION
├── OIDC authentication (no long-lived credentials)
├── IRSA / Workload Identity (pod-level IAM)
├── Non-root containers, read-only filesystem
├── Secrets via External Secrets Operator
│
Layer 4: DATA
├── Encryption at rest (KMS CMK / Key Vault CMK)
├── Encryption in transit (TLS 1.3, mTLS)
├── PHI tokenization (no PHI in logs)
├── Data classification tags on all storage
│
Layer 5: MONITORING
├── GuardDuty + Defender for Cloud (threat detection)
├── Security Hub + Defender (compliance dashboard)
├── CloudTrail + Azure Activity Log (audit)
├── AWS Config + Azure Policy (compliance rules)
```

### 6.2 IAM Strategy

- **No long-lived credentials** — OIDC for CI/CD (GitHub → AWS/Azure)
- **IRSA** (EKS) — each service has its own IAM role via ServiceAccount annotation
- **Workload Identity** (AKS) — Azure AD mapped to K8s ServiceAccounts
- **Least privilege** — scoped to specific S3 buckets, DynamoDB tables, etc.

---

## 7. DR Strategy

### 7.1 Failover Architecture

```
                    NORMAL OPERATION
                    ================
  Route 53 ──→ AWS (PRIMARY, weight=100) ──→ EKS ──→ Aurora (writer)
           └── Azure (STANDBY, weight=0) ──→ AKS ──→ PG Flex (read-only)

                    FAILOVER ACTIVE
                    ================
  Route 53 ──→ AWS (UNHEALTHY, skip) ──→ X
           └── Azure (ACTIVE, weight=100) ──→ AKS (scaled up) ──→ PG Flex (promoted)
```

### 7.2 Failover Sequence

| Step | Action | Duration | Automation |
|------|--------|----------|------------|
| 1 | Route 53 detects primary unhealthy | ~60s | Automatic (10s interval, 3 failures) |
| 2 | DNS failover to Azure Traffic Manager | ~60s | Automatic |
| 3 | AKS auto-scales from 2 → 5+ nodes | ~3-5min | Automatic (cluster autoscaler) |
| 4 | PostgreSQL promote replica to primary | ~5-10min | Manual (scripts/ops/dr-failover.sh) |
| 5 | Application health checks pass | ~5min | Automatic (K8s probes) |
| **Total** | | **~15-25min** | **Target: < 30min ✅** |

### 7.3 Monthly DR Test

Automated via `.github/workflows/dr-failover-test.yml`:
1. Validate infrastructure parity (AWS ↔ Azure)
2. Check Route 53 health check status
3. Verify Aurora replication lag
4. Confirm AKS warm standby is running
5. Calculate RTO/RPO estimates
6. Generate compliance report (retained 365 days per HIPAA)

---

## 8. Observability

| Layer | AWS | Azure |
|-------|-----|-------|
| Metrics | CloudWatch + Prometheus | Azure Monitor |
| Logs | CloudWatch Logs (encrypted) | Log Analytics Workspace |
| Traces | AWS X-Ray | Application Insights |
| Dashboards | CloudWatch Dashboard | Azure Dashboard |
| Alerts | SNS → Email/PagerDuty | Monitor Action Groups |
| Service Mesh | Istio (Kiali, Jaeger) | Istio (Kiali, Jaeger) |

**Critical Alarms:**
- Aurora CPU > 80% (15min)
- Aurora replication lag > 5min (DR-critical)
- EKS node CPU > 85%
- Primary endpoint unhealthy (DR-trigger)

---

## 9. CI/CD Architecture

```
Developer ──→ Feature Branch ──→ PR ──→ main ──→ Production
                                  │
                    ┌─────────────┼──────────────┐
                    │             │              │
              Security Scan  Terraform Plan  App Build
              (sec_scanner)  (tfsec+Checkov) (Docker+Trivy)
                    │             │              │
                    └─────────────┼──────────────┘
                                  │
                           Manual Approval
                                  │
                    ┌─────────────┼──────────────┐
                    │             │              │
              Terraform Apply  ECR/ACR Push   ArgoCD Sync
              (sequential)     (both clouds)  (both clusters)
```

---

## 10. Technology Stack Summary

| Category | Technology | Version |
|----------|-----------|---------|
| IaC | Terraform | >= 1.5 |
| Container Orchestration | EKS + AKS | 1.30 |
| Service Mesh | Istio | 1.22 |
| GitOps | ArgoCD | Latest |
| CI/CD | GitHub Actions | N/A |
| Primary Database | Aurora PostgreSQL | 16.1 |
| DR Database | Azure DB PostgreSQL Flex | 16 |
| Cache | ElastiCache Redis / Azure Redis | 7.1 |
| Object Storage | S3 / Azure Blob | N/A |
| CDN | CloudFront | N/A |
| WAF | AWS WAF v2 / Azure WAF | N/A |
| DNS | Route 53 + Azure Traffic Manager | N/A |
| Secrets | AWS Secrets Manager + Azure Key Vault | N/A |
| Monitoring | CloudWatch + Azure Monitor + Prometheus | N/A |
| Security | GuardDuty + Defender for Cloud | N/A |
| DevOps Automation | Claude Code for DevOps | N/A |
