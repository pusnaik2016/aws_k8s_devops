# Architecture — EKS Retail Platform

## System Overview

The EKS Retail Platform is a production-grade microservices architecture deployed on Amazon EKS with dual autoscaling, Istio service mesh, and multi-framework compliance (PCI-DSS, SOC2, HIPAA, GDPR).

## Data Flow

```
                            ┌─────────────────┐
                            │   CloudFront     │
                            │   (CDN + WAF)    │
                            └────────┬────────┘
                                     │ HTTPS
                            ┌────────▼────────┐
                            │  Istio Gateway   │
                            │  TLS 1.2+        │
                            │  mTLS STRICT     │
                            └────────┬────────┘
                                     │
                    ┌────────────────┼────────────────┐
                    │                │                  │
           ┌───────▼────────┐  ┌────▼──────┐  ┌──────▼────────┐
           │  storefront-api│  │  Static   │  │  Admin API    │
           │  (Products)    │  │  Assets   │  │  (Internal)   │
           │  HPA: 0→15    │  │  (S3)     │  │               │
           └───────┬────────┘  └───────────┘  └───────────────┘
                   │
        ┌──────────┼──────────────┐
        │                         │
┌───────▼────────┐  ┌────────────▼──────────┐
│  order-service │  │  inventory-service    │
│  SQS Consumer  │  │  Stock Management    │
│  KEDA: 0→20   │  │  HPA: 0→10          │
└───────┬────────┘  └──────────────────────┘
        │
        ├──── SQS (FIFO) ────► Order Queue
        │
┌───────▼────────┐
│ payment-service│
│ PCI Namespace  │
│ HPA: 2→10     │
│ (always-on)    │
└───────┬────────┘
        │
        ├──── SNS ──────────► Order Events Topic
        │                            │
        │                    ┌───────▼──────────┐
        │                    │  SQS Notification │
        │                    │  Queue            │
        │                    └───────┬──────────┘
        │                    ┌───────▼──────────┐
        │                    │ notification-svc  │
        │                    │ KEDA: 0→10       │
        │                    │ Email/SMS         │
        │                    └──────────────────┘
        │
┌───────▼────────┐
│ Aurora PgSQL   │
│ Serverless v2  │
│ Multi-AZ (prod)│
│ KMS Encrypted  │
└────────────────┘
```

## Network Architecture

### VPC Design (3-Tier, 3-AZ)

| Subnet Tier | CIDR Pattern | Purpose | Resources |
|---|---|---|---|
| **Public** | x.x.{1,2,3}.0/24 | Internet-facing | ALB, NAT Gateways |
| **Private** | x.x.{11,12,13}.0/24 | Compute | EKS nodes, pods |
| **Database** | x.x.{21,22,23}.0/24 | Data tier | Aurora, ElastiCache |

### VPC Endpoints (Private Link)
All AWS service traffic stays within VPC:
- `com.amazonaws.*.s3` (Gateway)
- `com.amazonaws.*.ecr.api` + `ecr.dkr` (Interface)
- `com.amazonaws.*.sts` (Interface — for IRSA)
- `com.amazonaws.*.logs` (Interface — for FluentBit)
- `com.amazonaws.*.sqs` (Interface — for KEDA/services)

## Node Architecture

### System Nodes (Managed Node Group)
- **Purpose**: Bootstrap Karpenter, CoreDNS, kube-proxy
- **AMI**: Bottlerocket (minimal attack surface)
- **Type**: m6i.large (prod: m6i.xlarge)
- **Capacity**: ON_DEMAND only
- **Taint**: `CriticalAddonsOnly=true:NoSchedule`

### Karpenter Default NodePool
- **Workloads**: All non-PCI application pods
- **Families**: m7g, m6i, c7g, c6i, r7g, r6i (Graviton + Intel)
- **Capacity**: Spot + On-Demand mix
- **Consolidation**: WhenEmptyOrUnderutilized (60s)
- **IMDSv2**: Required (httpTokens=required)

### Karpenter PCI-Compliant NodePool
- **Workloads**: payment-service only
- **Families**: m6i, c6i, r6i (Nitro — HW encryption)
- **Capacity**: ON_DEMAND only (no Spot)
- **EBS**: KMS-encrypted with customer-managed key
- **Taint**: `compliance=pci-hipaa:NoSchedule`
- **Consolidation**: WhenEmpty (300s — conservative)

## Security Architecture

### IAM Model
```
                    ┌─────────────────┐
                    │  OIDC Provider   │
                    │  (EKS Cluster)   │
                    └────────┬────────┘
                             │ IRSA
            ┌────────────────┼────────────────┐
            │                │                 │
    ┌───────▼──────┐ ┌──────▼──────┐ ┌───────▼───────┐
    │ Karpenter    │ │ FluentBit   │ │ KEDA Operator │
    │ Controller   │ │ DaemonSet   │ │               │
    │ EC2/SSM/SQS  │ │ CW Logs     │ │ SQS GetAttr   │
    └──────────────┘ └─────────────┘ └───────────────┘
            │
    ┌───────▼──────┐
    │ Service IRSA │
    │ Roles        │
    ├──────────────┤
    │ order-svc    │→ SQS:Receive, SNS:Publish
    │ notif-svc    │→ SQS:Receive, SES:Send
    │ payment-svc  │→ KMS:Encrypt/Decrypt
    └──────────────┘
```

### Encryption Model
| Data State | Method | Key |
|---|---|---|
| K8s Secrets at rest | Envelope encryption | Dedicated EKS KMS key |
| Aurora at rest | Storage encryption | General KMS key |
| EBS volumes (PCI nodes) | Volume encryption | General KMS key |
| S3 (CloudTrail, backups) | SSE-KMS | General KMS key |
| In-transit (mesh) | Istio mTLS STRICT | Auto-rotated certs |
| In-transit (external) | TLS 1.2+ | ACM certificate |
| SQS messages | SSE-KMS | General KMS key |
| CloudWatch Logs | SSE-KMS | General KMS key |

## Autoscaling Architecture

### Decision Matrix: KEDA vs Native HPA

```
                     ┌─────────────────────┐
                     │ Scaling Trigger?     │
                     └──────────┬──────────┘
                                │
                ┌───────────────┼───────────────┐
                │               │               │
        ┌───────▼──────┐  ┌────▼─────┐  ┌─────▼──────┐
        │ SQS/SNS/     │  │ HTTP RPS │  │ CPU/Memory │
        │ Kafka/       │  │ External │  │ Resource   │
        │ Event Queue  │  │ Metric   │  │ Metric     │
        └───────┬──────┘  └────┬─────┘  └─────┬──────┘
                │              │               │
        ┌───────▼──────┐  ┌────▼──────┐  ┌────▼──────┐
        │    KEDA       │  │ Native   │  │ Standard  │
        │ ScaledObject  │  │ HPA v2   │  │ HPA v2    │
        │ scale-to-zero │  │ K8s 1.36+│  │ min >= 1  │
        └──────────────┘  └──────────┘  └──────────┘
```

## GitOps Deployment Model

```
Developer → PR → GitHub Actions CI
                   ├── SAST (SonarCloud)
                   ├── SCA (OWASP + Safety)
                   ├── Unit Tests + Coverage
                   └── Build + Trivy Scan
                          │
                          ▼ (merge to main)
                   GitHub Actions CD
                   ├── Push to ECR (immutable tag)
                   ├── Update K8s manifest (sed image tag)
                   ├── Git commit + push
                   └── DORA Metrics Collection
                          │
                          ▼ (manifest change detected)
                   ArgoCD Auto-Sync
                   ├── Wave 0: Base (namespaces, RBAC)
                   ├── Wave 1: Karpenter NodePools
                   ├── Wave 2: Istio config
                   ├── Wave 3: KEDA + HPA
                   ├── Wave 4: FluentBit
                   └── Wave 5: App deployments
```
