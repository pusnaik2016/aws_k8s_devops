# Security Architecture — OmniPresenseAI

> Defense-in-depth security architecture for the Omnichannel AI-Powered Customer Support & Analytics Platform.

---

## Table of Contents

1. [Security Overview](#security-overview)
2. [Network Security](#network-security)
3. [Identity & Access Management](#identity--access-management)
4. [Encryption](#encryption)
5. [Secrets Management](#secrets-management)
6. [Container Security](#container-security)
7. [CI/CD Security](#cicd-security)
8. [Compliance Mapping](#compliance-mapping)

---

## Security Overview

```mermaid
graph TB
    subgraph "Perimeter"
        WAF["AWS WAF"] --> CF["CloudFront<br>TLS 1.3"]
        CF --> APIGW["API Gateway<br>Throttling + Auth"]
    end

    subgraph "Network Isolation"
        APIGW --> ALB["ALB<br>Public Subnet"]
        ALB --> EKS["EKS Pods<br>Private Subnet"]
        EKS --> AURORA["Aurora<br>Private Subnet"]
        EKS --> REDIS["Redis<br>Private Subnet"]
    end

    subgraph "Identity"
        OIDC["GitHub OIDC<br>Zero Credentials"]
        IRSA["IRSA<br>Pod-Level IAM"]
        KMS["KMS<br>Envelope Encryption"]
    end

    subgraph "Data Protection"
        SSM["SSM SecureString<br>Secrets"]
        S3ENC["S3 SSE-KMS<br>Encryption"]
        DBENC["Aurora KMS<br>Encryption"]
    end

    OIDC -.-> ALB
    IRSA -.-> EKS
    KMS -.-> DBENC
    KMS -.-> S3ENC

    style WAF fill:#e74c3c,color:#fff
    style OIDC fill:#2ecc71,color:#fff
    style KMS fill:#e74c3c,color:#fff
    style IRSA fill:#2ecc71,color:#fff
```

---

## Network Security

### VPC Architecture

| Component | CIDR/Config | Purpose |
|-----------|-------------|---------|
| VPC | `10.0.0.0/16` | Isolated network (65,536 IPs) |
| Public Subnets (3) | `10.0.1.0/24`, `10.0.2.0/24`, `10.0.3.0/24` | ALB, NAT Gateway |
| Private Subnets (3) | `10.0.11.0/24`, `10.0.12.0/24`, `10.0.13.0/24` | EKS, Aurora, Redis |
| NAT Gateway | Single AZ (cost optimization) | Outbound internet for private subnets |
| Internet Gateway | — | Inbound for public subnets |

### Security Groups

```mermaid
graph LR
    subgraph "Inbound Rules"
        INET["Internet<br>0.0.0.0/0"] -->|443| ALB_SG["ALB SG"]
        ALB_SG -->|8000,8001| EKS_SG["EKS Nodes SG"]
        EKS_SG -->|5432| AURORA_SG["Aurora SG"]
        EKS_SG -->|6379| REDIS_SG["Redis SG"]
    end

    style ALB_SG fill:#f39c12,color:#fff
    style EKS_SG fill:#2ecc71,color:#fff
    style AURORA_SG fill:#3b48cc,color:#fff
    style REDIS_SG fill:#dc382c,color:#fff
```

| Security Group | Inbound | Source | Port |
|---------------|---------|--------|------|
| ALB | HTTPS | `0.0.0.0/0` | 443 |
| EKS Nodes | App traffic | ALB SG | 8000, 8001 |
| EKS Nodes | Cluster comms | Self | All |
| Aurora | PostgreSQL | EKS Nodes SG | 5432 |
| Redis | Redis | EKS Nodes SG | 6379 |

### Network Policies (Kubernetes)

```yaml
# Only chat-service can reach Aurora and Redis
# Only ALB can reach service ports
# Inter-pod traffic denied by default
```

Implemented in `k8s/base/network-policies.yaml`:
- `chat-service` → Aurora (5432), Redis (6379), Bedrock (443)
- `analytics-service` → Aurora (5432), S3 (443), Bedrock (443)
- Deny all other inter-namespace traffic

### VPC Flow Logs

- **Destination:** CloudWatch Logs
- **Traffic type:** REJECT only (minimize cost)
- **Retention:** 30 days
- **Purpose:** Network forensics, anomaly detection

---

## Identity & Access Management

### OIDC Federation (CI/CD)

```mermaid
sequenceDiagram
    participant GH as GitHub Actions
    participant OIDC as AWS OIDC Provider
    participant STS as AWS STS
    participant TF as Terraform / kubectl

    GH->>GH: Generate OIDC JWT
    GH->>OIDC: Present JWT token
    OIDC->>STS: Validate + AssumeRoleWithWebIdentity
    STS-->>GH: Temporary credentials (1 hour)
    GH->>TF: Execute with temp creds

    Note over GH,TF: Zero static credentials stored in GitHub
```

**Trust Policy Conditions:**
- `token.actions.githubusercontent.com:sub` → `repo:pusnaik2016/OmniPresenseAI:ref:refs/heads/main`
- `token.actions.githubusercontent.com:aud` → `sts.amazonaws.com`
- Only `main` branch can assume the deploy role

### IRSA (Pod-Level IAM)

| Service Account | IAM Role | Permissions |
|----------------|----------|-------------|
| `chat-service` | `omnipresense-ai-chat-irsa` | Bedrock InvokeModel, SSM GetParameter, S3 GetObject |
| `analytics-service` | `omnipresense-ai-analytics-irsa` | Bedrock InvokeModel, S3 PutObject, SSM GetParameter |

**IRSA Flow:**
1. K8s ServiceAccount annotated with IAM role ARN
2. EKS injects OIDC-signed JWT into pod
3. AWS SDK exchanges JWT for temporary credentials
4. Pod assumes role with **only** its assigned permissions

```mermaid
graph LR
    SA["K8s ServiceAccount<br>Annotation: IAM Role ARN"] --> OIDC["EKS OIDC Provider"]
    OIDC --> STS["AWS STS"]
    STS --> CREDS["Temporary Credentials<br>Scoped to role"]
    CREDS --> POD["Pod → AWS API calls"]

    style SA fill:#2ecc71,color:#fff
    style CREDS fill:#f39c12,color:#fff
```

### Least Privilege Policies

All IAM policies follow least privilege:
- Resource-level ARN restrictions (not `*`)
- Action-level granularity (e.g., `bedrock:InvokeModel` only, not `bedrock:*`)
- Condition keys where applicable (e.g., `aws:RequestedRegion`)

---

## Encryption

### KMS Key Hierarchy

| Key Alias | Purpose | Rotation | Used By |
|-----------|---------|----------|---------|
| `omnipresense-ai-eks` | EKS Secrets encryption | Annual (auto) | EKS control plane |
| `omnipresense-ai-aurora` | Aurora encryption at rest | Annual (auto) | Aurora cluster |
| `omnipresense-ai-s3` | S3 bucket encryption | Annual (auto) | S3 frontend + data |

### Encryption in Transit

| Connection | Protocol | Min Version |
|-----------|----------|-------------|
| User → CloudFront | TLS | 1.3 |
| CloudFront → API GW | TLS | 1.2 |
| ALB → EKS pods | TLS | 1.2 |
| EKS → Aurora | TLS | 1.2 (enforced via `rds.force_ssl`) |
| EKS → Redis | TLS | 1.2 (in-transit encryption enabled) |
| EKS → Bedrock | TLS | 1.2 (AWS SDK default) |

### Encryption at Rest

| Service | Method | Key |
|---------|--------|-----|
| Aurora PostgreSQL | AES-256 | KMS CMK (`omnipresense-ai-aurora`) |
| ElastiCache Redis | AES-256 | KMS CMK (AWS managed) |
| S3 Buckets | SSE-KMS | KMS CMK (`omnipresense-ai-s3`) |
| EKS Secrets | Envelope encryption | KMS CMK (`omnipresense-ai-eks`) |

---

## Secrets Management

### SSM Parameter Store

| Parameter Path | Type | Purpose |
|---------------|------|---------|
| `/omnipresense-ai/prod/aurora/master-password` | SecureString | Aurora master password |
| `/omnipresense-ai/prod/redis/auth-token` | SecureString | Redis AUTH token |

**Access Pattern:**
- Stored as `SecureString` (encrypted with KMS)
- Referenced by Terraform via SSM ARN (never in plain text)
- Pods read at startup via IRSA + SSM `GetParameter`
- No secrets in environment variables, ConfigMaps, or Git

### Secrets Never In:

- ❌ GitHub Secrets (except `AWS_DEPLOY_ROLE_ARN` and `AWS_ACCOUNT_ID`)
- ❌ Terraform `.tfvars` files (use SSM references)
- ❌ Docker images
- ❌ Kubernetes ConfigMaps
- ❌ Application logs

---

## Container Security

### Dockerfile Best Practices

Both microservices follow:

```dockerfile
# Multi-stage build (minimize image size)
FROM python:3.11-slim AS builder
# ... install dependencies ...

FROM python:3.11-slim
# Non-root user
RUN useradd -r -s /bin/false appuser
USER appuser

# Read-only filesystem
# (enforced via K8s securityContext)
```

### Kubernetes Security Context

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop: [ALL]
```

### Image Scanning

- **Trivy** scans in CI pipeline (CRITICAL + HIGH severity)
- **ECR image scanning** enabled on push
- Base image `python:3.11-slim` — minimal attack surface

---

## CI/CD Security

### Pipeline Security Controls

```mermaid
graph LR
    PR["Pull Request"] --> LINT["Ruff Linter"]
    LINT --> TEST["Unit Tests"]
    TEST --> CHECKOV["Checkov<br>IaC Scan"]
    CHECKOV --> TRIVY["Trivy<br>Container Scan"]
    TRIVY --> MERGE["Merge to main"]
    MERGE --> OIDC["OIDC Auth<br>No static creds"]
    OIDC --> DEPLOY["Deploy"]

    style CHECKOV fill:#e74c3c,color:#fff
    style TRIVY fill:#e74c3c,color:#fff
    style OIDC fill:#2ecc71,color:#fff
```

| Control | Tool | Stage |
|---------|------|-------|
| Code linting | Ruff | PR CI |
| Unit tests | pytest | PR CI |
| IaC security scan | Checkov | PR CI |
| Dependency vulnerability scan | Trivy | PR CI |
| Credential-less deployment | GitHub OIDC | CD |
| Environment protection | GitHub Environments | CD |

---

## Compliance Mapping

### SOC 2 Type II Controls

| Control | Implementation |
|---------|---------------|
| CC6.1 — Logical access | IRSA, OIDC, least privilege IAM |
| CC6.2 — Network security | VPC, private subnets, SGs, NACLs |
| CC6.3 — Data in transit | TLS 1.2+ everywhere |
| CC6.4 — Data at rest | KMS encryption (Aurora, S3, EKS) |
| CC7.1 — Change management | GitHub PR reviews, CI gates |
| CC7.2 — System monitoring | CloudWatch, VPC Flow Logs |
| CC8.1 — Vulnerability management | Trivy, Checkov in CI |

### AWS Well-Architected Alignment

| Pillar | Key Controls |
|--------|-------------|
| **Security** | OIDC, IRSA, KMS, VPC isolation, WAF |
| **Reliability** | Multi-AZ, PDB, HPA/KEDA, Aurora Serverless |
| **Performance** | CloudFront CDN, Redis cache, Graviton instances |
| **Cost Optimization** | Serverless Aurora, single NAT, S3 lifecycle |
| **Operational Excellence** | IaC (Terraform), CI/CD, monitoring |
| **Sustainability** | Graviton (ARM), right-sized instances |
