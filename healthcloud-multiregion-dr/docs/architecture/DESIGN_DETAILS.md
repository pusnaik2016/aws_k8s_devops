# HealthCloud — Design Details Document

## 1. Design Principles

| # | Principle | Implementation |
|---|-----------|----------------|
| 1 | **Security by Default** | All encryption enabled, zero-trust networking, non-root containers |
| 2 | **Compliance First** | HIPAA controls baked into IaC, not bolted on |
| 3 | **Immutable Infrastructure** | Terraform-managed, no manual changes, GitOps deployment |
| 4 | **Least Privilege** | IRSA per service, scoped IAM policies, no wildcards |
| 5 | **Observable Everything** | Full telemetry: metrics, logs, traces, audit trails |
| 6 | **DR as Code** | Failover infrastructure is Terraform-managed, tested monthly |
| 7 | **Shift Left Security** | Security scanning in CI before production deployment |

---

## 2. Microservice Design

### 2.1 Service Decomposition

```
┌────────────────────────────────────────────────────────────────┐
│                    Istio Ingress Gateway                       │
│                    (TLS termination, routing)                  │
└────┬──────────┬──────────┬──────────┬────────────────────────┘
     │          │          │          │
┌────▼────┐ ┌──▼────┐ ┌──▼──────┐ ┌─▼──────────┐
│Patient  │ │Imaging│ │Pharmacy │ │Notification│
│Service  │ │Service│ │Service  │ │Service     │
│(Java 21)│ │(Java) │ │(Java)   │ │(Python)    │
│         │ │       │ │         │ │            │
│ CRUD    │ │ DICOM │ │ Rx      │ │ Email/SMS  │
│ FHIR    │ │ Store │ │ Orders  │ │ Push       │
│ Search  │ │ View  │ │ Drug DB │ │ Templates  │
└────┬────┘ └──┬────┘ └──┬──────┘ └────────────┘
     │         │         │
     └─────────┼─────────┘
               │
        ┌──────▼──────┐
        │Aurora / PG  │
        │(encrypted)  │
        └─────────────┘
```

### 2.2 Service Communication Matrix

| From \ To | Patient | Imaging | Pharmacy | Notification | External |
|-----------|---------|---------|----------|-------------|----------|
| **Patient** | — | ✅ gRPC | ✅ REST | ✅ async | ✅ FHIR |
| **Imaging** | ❌ | — | ❌ | ✅ async | ✅ PACS |
| **Pharmacy** | ✅ REST | ❌ | — | ✅ async | ✅ Surescripts |
| **Notification** | ❌ | ❌ | ❌ | — | ✅ SNS/SES |

**Enforcement:** Istio AuthorizationPolicy restricts inter-service traffic to only the paths shown above. All other traffic is denied by default.

---

## 3. Database Design Decisions

### 3.1 Why Aurora PostgreSQL Global Database?

| Requirement | Aurora Global DB Solution |
|------------|--------------------------|
| Cross-region replication | Built-in, < 1s latency for reads |
| RPO < 15 min | Async replication meets target |
| HIPAA encryption | KMS CMK encryption at rest |
| Auto-failover | Managed failover with < 1 min RTO (same-region) |
| 7-year retention | Automated backups, snapshots to S3 Glacier |

### 3.2 Why Azure DB for PostgreSQL Flex (not Aurora)?

Cross-cloud replication uses **logical replication** since Aurora Global Database doesn't natively support Azure as a secondary:

```
Aurora PostgreSQL ──── pglogical ────→ Azure DB PostgreSQL Flex
     (writer)                              (subscriber)
```

**Configuration:**
- Publication on Aurora: all tables in `healthcloud` database
- Subscription on Azure: receives changes with ~1-5 min lag
- Monitoring: Custom CloudWatch metric for replication lag

### 3.3 DynamoDB Global Tables

Used for session management — not PHI data:
- **PAY_PER_REQUEST** billing (variable healthcare traffic)
- **TTL** enabled (auto-expire sessions)
- **PITR** enabled (point-in-time recovery)
- **KMS CMK** encryption

---

## 4. Kubernetes Design Decisions

### 4.1 Security Context Standard

Every workload follows this hardened security context:

```yaml
securityContext:
  runAsNonRoot: true          # No root processes
  runAsUser: 1000             # Dedicated user
  fsGroup: 1000               # File system group
  seccompProfile:
    type: RuntimeDefault       # Restrict syscalls
  allowPrivilegeEscalation: false  # No privilege escalation
  readOnlyRootFilesystem: true     # Immutable filesystem
  capabilities:
    drop: ["ALL"]              # Drop all Linux capabilities
```

### 4.2 Why Istio Over Linkerd?

| Criteria | Istio | Linkerd |
|----------|-------|---------|
| mTLS enforcement | ✅ STRICT mode | ✅ |
| AuthorizationPolicy | ✅ L7 granular | ❌ Limited |
| Multi-cluster | ✅ Primary-Remote | ✅ Multi-cluster |
| Traffic management | ✅ VirtualService, DestinationRule | Limited |
| Observability | ✅ Kiali, Jaeger, Prometheus | ✅ But lighter |
| **Decision** | **Selected** — need L7 AuthorizationPolicy for HIPAA inter-service controls |

### 4.3 HPA Strategy

| Service | Min Replicas | Max | CPU Target | Memory Target |
|---------|-------------|-----|------------|---------------|
| patient-service | 3 | 10 | 70% | 80% |
| imaging-service | 2 | 8 | 70% | — |
| pharmacy-service | 2 | 6 | 70% | — |
| notification-service | 2 | 6 | 75% | — |

**Scale-down protection:** 300s stabilization window, max 10% per minute.

---

## 5. CI/CD Design Decisions

### 5.1 Why OIDC Over Static Credentials?

```
GitHub Actions ──(OIDC JWT)──→ AWS STS ──→ Temporary credentials (1hr)
                                          (no stored secrets)
```

Benefits:
- No long-lived AWS keys in GitHub Secrets
- Automatic credential rotation (per-job)
- Auditable via CloudTrail (which GitHub repo/workflow assumed which role)
- Reduced blast radius

### 5.2 Pipeline Security Gates

```
Code Change
    │
    ├── Gate 1: Secret Detection (sec_scanner.py) ──→ BLOCK if secrets found
    ├── Gate 2: Static Analysis (tfsec + Checkov) ──→ WARN on misconfig
    ├── Gate 3: Container Scan (Trivy) ──→ BLOCK on CRITICAL/HIGH CVEs
    ├── Gate 4: Compliance Check (compliance_checker.py) ──→ REPORT
    ├── Gate 5: Manual Approval (prod only) ──→ Required
    │
    └── Deploy (ArgoCD GitOps)
```

### 5.3 ArgoCD Multi-Cluster Strategy

| Cluster | Role | ArgoCD App | Sync Mode |
|---------|------|-----------|-----------|
| AWS EKS | Primary | healthcloud-aws-apps | Auto-sync, self-heal, prune |
| Azure AKS | DR | healthcloud-azure-dr-apps | Auto-sync, self-heal, prune |

Both clusters deploy the same manifests from `kubernetes/apps/` — ensuring parity.

---

## 6. Encryption Design

### 6.1 Key Management

```
AWS KMS CMK                           Azure Key Vault (Premium)
├── Aurora encryption                  ├── PostgreSQL encryption
├── S3 bucket encryption               ├── Blob Storage encryption
├── EBS volume encryption              ├── AKS secret encryption
├── CloudTrail log encryption          ├── Log Analytics encryption
├── SNS topic encryption               ├── Redis encryption
└── Key rotation: automatic (annual)   └── Soft delete: 90 days
```

### 6.2 PHI Data Flow

```
Patient App ──(TLS 1.3)──→ CloudFront ──(TLS 1.3)──→ ALB ──(mTLS)──→ Pod
                                                                        │
                                                         ┌──────────────┤
                                                         │              │
                                                   ┌─────▼─────┐ ┌─────▼─────┐
                                                   │ Aurora PG  │ │ S3 PHI    │
                                                   │ (KMS CMK)  │ │ (SSE-KMS) │
                                                   │ encrypted  │ │ Object    │
                                                   │ at rest    │ │ Lock      │
                                                   └────────────┘ └───────────┘
```

PHI is **never** in:
- Environment variables
- Application logs (masked/tokenized)
- Container image layers
- Git repository

---

## 7. Tagging Strategy

Every cloud resource has these mandatory tags:

| Tag Key | Purpose | Example Values |
|---------|---------|----------------|
| `Project` | Cost allocation | healthcloud |
| `Environment` | Environment identification | dev, staging, prod |
| `ManagedBy` | IaC tracking | terraform |
| `Owner` | Team ownership | platform-team |
| `Compliance` | Regulatory framework | hipaa, gdpr, soc2 |
| `DataClassification` | Data sensitivity level | phi, confidential, internal, public |

---

## 8. Cost Optimization

| Strategy | Implementation |
|----------|----------------|
| Graviton instances (EKS) | ~20% cost reduction vs x86 |
| Spot instances (dev/staging) | ~60% savings on non-prod nodes |
| S3 Intelligent Tiering | Auto-archive old PHI to Glacier |
| Azure DR warm standby | 2 nodes instead of full parity (save ~70%) |
| VPC Endpoints | Avoid NAT Gateway data charges for AWS services |
| Reserved Instances | Aurora & ElastiCache RIs for prod |

---

## 9. Disaster Recovery Cost Model

| Component | Normal State (monthly) | DR Active (monthly) |
|-----------|----------------------|---------------------|
| AWS EKS | $1,500 (3 nodes) | $1,500 |
| Azure AKS | $600 (2 nodes, standby) | $2,500 (8 nodes, active) |
| Aurora Global DB | $2,000 | $2,000 |
| Azure PostgreSQL | $800 | $800 |
| VPN Gateway | $150 | $150 |
| **Total** | **~$5,050** | **~$6,950** |

DR adds ~$1,900/month (~38% overhead) for multi-cloud redundancy — justified for HIPAA-compliant healthcare.
