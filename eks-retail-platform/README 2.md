# EKS Retail Platform

> Production-grade Kubernetes platform on AWS EKS with dual autoscaling (KEDA + Native HPA), Karpenter node management, Istio service mesh, ArgoCD GitOps, and full compliance (PCI-DSS, SOC2, HIPAA, GDPR).

---

## 🏗️ Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         AWS Cloud (us-east-1)                                │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │  VPC (10.x.0.0/16) — 3 AZs, 3-Tier Subnets                         │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐                           │  │
│  │  │ Public   │  │ Private  │  │ Database │                           │  │
│  │  │ (ALB)    │  │ (EKS)    │  │ (Aurora) │                           │  │
│  │  └──────────┘  └──────────┘  └──────────┘                           │  │
│  │           │           │              │                               │  │
│  │  ┌────────────────────────────────────────────────────────────────┐  │  │
│  │  │  EKS Cluster (K8s 1.31) — Private API (prod)                 │  │  │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌───────────────┐         │  │  │
│  │  │  │ System      │  │ Default     │  │ PCI-Compliant │         │  │  │
│  │  │  │ Node Group  │  │ NodePool    │  │ NodePool      │         │  │  │
│  │  │  │ (Managed)   │  │ (Karpenter) │  │ (Karpenter)   │         │  │  │
│  │  │  │ Bottlerocket│  │ Graviton+   │  │ On-Demand     │         │  │  │
│  │  │  │             │  │ Spot Mix    │  │ Nitro+KMS     │         │  │  │
│  │  │  └─────────────┘  └─────────────┘  └───────────────┘         │  │  │
│  │  │                                                               │  │  │
│  │  │  ┌── Namespaces ──────────────────────────────────────────┐   │  │  │
│  │  │  │  retail-apps:  storefront-api, order-svc, inventory    │   │  │  │
│  │  │  │  payment:      payment-service (PCI isolated)          │   │  │  │
│  │  │  │  istio-system: Ingress Gateway + mTLS                  │   │  │  │
│  │  │  │  keda:         KEDA Operator                           │   │  │  │
│  │  │  │  argocd:       GitOps Controller                       │   │  │  │
│  │  │  │  fluentbit:    Log Aggregation (PII masking)           │   │  │  │
│  │  │  └────────────────────────────────────────────────────────┘   │  │  │
│  │  └──────────────────────────────────────────────────────────────┘  │  │
│  │           │                              │                         │  │
│  │  ┌────────┴──────────┐  ┌───────────────┴─────────────────┐       │  │
│  │  │ Aurora PostgreSQL │  │ SQS (FIFO+Std) + SNS + SES     │       │  │
│  │  │ Serverless v2     │  │ (KEDA Trigger Sources)          │       │  │
│  │  │ Multi-AZ (prod)   │  └─────────────────────────────────┘       │  │
│  │  └───────────────────┘                                            │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌── Security ──────────────────────────────────────────────────────────┐│
│  │ CloudTrail │ GuardDuty │ Security Hub │ WAF v2 │ KMS │ ECR Scanning ││
│  └──────────────────────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────────────────────────┘
```

## 🚀 Dual Autoscaling Strategy

| Service | Scaling | Trigger | Min→Max | Zero-Capable |
|---|---|---|---|---|
| `storefront-api` | **Native HPA** | External metric (HTTP RPS) | 0→15 | ✅ K8s 1.36+ |
| `order-service` | **KEDA** | SQS queue depth | 0→20 | ✅ ScaledObject |
| `inventory-service` | **Native HPA** | External metric (HTTP RPS) | 0→10 | ✅ K8s 1.36+ |
| `payment-service` | **Standard HPA** | CPU/Memory | 2→10 | ❌ PCI: always-on |
| `notification-service` | **KEDA** | SQS queue depth | 0→10 | ✅ ScaledObject |

**Decision guide:** Use KEDA when the trigger source is a message queue (SQS/SNS). Use native HPA when scaling on standard or external metrics (HTTP, CPU). See [docs/keda-vs-hpa.md](docs/keda-vs-hpa.md).

## 📁 Project Structure

```
eks-retail-platform/
├── .github/workflows/           # CI/CD Pipelines
│   ├── infra-pipeline.yml       #   Terraform plan/apply (dev→staging→prod)
│   ├── app-pipeline.yml         #   Build, scan, push, deploy (matrix)
│   └── security-scan.yml        #   Weekly security scanning
├── terraform/                   # Infrastructure as Code
│   ├── modules/                 #   Reusable modules
│   │   ├── vpc/                 #   3-tier VPC + endpoints
│   │   ├── eks/                 #   EKS cluster + KMS + OIDC
│   │   ├── karpenter/           #   Node provisioning IAM + SQS
│   │   ├── security/            #   CloudTrail/GuardDuty/WAF/ECR
│   │   ├── database/            #   Aurora Serverless v2
│   │   ├── messaging/           #   SQS/SNS + IRSA roles
│   │   └── observability/       #   CloudWatch + FluentBit IRSA
│   ├── environments/            #   Environment configs
│   │   ├── dev/                 #   Cost-optimized
│   │   ├── staging/             #   HA + security
│   │   └── prod/                #   Full compliance
│   ├── variables.tf             #   Shared variables
│   └── versions.tf              #   Provider pinning
├── kubernetes/                  # K8s Manifests
│   ├── base/                    #   Namespaces, RBAC, quotas, network policies
│   ├── karpenter/               #   NodePools + EC2NodeClasses
│   ├── istio/                   #   mTLS, Gateway, VirtualServices, AuthZ
│   ├── keda/                    #   ScaledObjects + TriggerAuth
│   ├── hpa/                     #   Native HPA with scale-to-zero
│   ├── fluentbit/               #   Log config + PII masking
│   ├── argocd/                  #   App-of-apps (sync waves)
│   └── apps/                    #   Per-service deployments
├── apps/                        # Microservice Source Code
│   ├── storefront-api/          #   Product catalog (FastAPI)
│   ├── order-service/           #   Order processing (SQS consumer)
│   ├── inventory-service/       #   Stock management
│   ├── payment-service/         #   PCI-compliant payments
│   └── notification-service/    #   Email/SMS (SQS consumer)
├── scripts/                     # Operational scripts
│   └── bootstrap.sh             #   Initial cluster setup
└── docs/                        # Documentation
    ├── architecture.md          #   Detailed architecture
    ├── compliance.md            #   PCI-DSS/SOC2/HIPAA/GDPR controls
    ├── keda-vs-hpa.md           #   Autoscaling decision guide
    └── runbook.md               #   Operations runbook
```

## 🔒 Compliance Matrix

| Requirement | Control | Implementation |
|---|---|---|
| **PCI-DSS 1.3** | Network segmentation | VPC subnets, default-deny NetworkPolicies, payment namespace isolation |
| **PCI-DSS 3.4** | Encrypt stored data | KMS envelope encryption (EKS secrets, Aurora, S3, EBS) |
| **PCI-DSS 4.1** | Encrypt in transit | Istio STRICT mTLS, TLS 1.2+ on Gateway |
| **PCI-DSS 6.6** | Secure code + WAF | Trivy scanning, WAF v2 (SQLi, XSS, rate limiting) |
| **PCI-DSS 7** | Restrict access | RBAC, IRSA (least-privilege), Pod Security Standards |
| **PCI-DSS 8.2** | No shared credentials | IAM auth for Aurora, IRSA for AWS services |
| **SOC2 CC6.1** | Encryption | KMS auto-rotation, mTLS, encrypted log groups |
| **SOC2 CC7.2** | Audit logging | CloudTrail + EKS audit logs (365-day retention) |
| **HIPAA §164.312** | Access + encryption | IAM/RBAC, KMS, encrypted backups (35-day retention) |
| **GDPR Art. 25** | Data protection | PII masking in FluentBit, encrypted storage, data minimization |

## ⚡ Quick Start

### Prerequisites
- AWS CLI v2 + configured credentials
- Terraform >= 1.9
- kubectl >= 1.31
- Helm >= 3.15

### 1. Bootstrap Infrastructure
```bash
# Initialize Terraform state backend
./scripts/bootstrap.sh

# Deploy dev environment
cd terraform/environments/dev
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

### 2. Configure kubectl
```bash
aws eks update-kubeconfig --name eks-retail-dev-eks --region us-east-1
```

### 3. Install Platform Components
```bash
# Install Karpenter via Helm
helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
  --namespace kube-system --version 1.1.0 \
  --set "settings.clusterName=eks-retail-dev-eks" \
  --set "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=<KARPENTER_ROLE_ARN>"

# Install KEDA
helm upgrade --install keda kedacore/keda --namespace keda --create-namespace

# Install Istio
istioctl install --set profile=default -y

# Install ArgoCD
helm upgrade --install argocd argo/argo-cd --namespace argocd --create-namespace

# Apply base manifests
kubectl apply -f kubernetes/base/ --recursive
kubectl apply -f kubernetes/argocd/applications/app-of-apps.yaml
```

### 4. CI/CD Setup
Configure these GitHub repository secrets:
| Secret | Description |
|---|---|
| `AWS_ROLE_DEV` | IAM role ARN for dev deployments |
| `AWS_ROLE_STAGING` | IAM role ARN for staging |
| `AWS_ROLE_PROD` | IAM role ARN for production |

## 📊 Monitoring

- **CloudWatch Dashboard**: `eks-retail-{env}-retail-platform`
- **Grafana**: Via Istio telemetry + Prometheus
- **Logs**: CloudWatch Log Groups (`/eks/{cluster}/retail-apps`, `/eks/{cluster}/payment`)
- **Alerts**: SQS DLQ depth, pod restart count, API error rate

## 📚 Documentation

| Document | Description |
|---|---|
| [Architecture](docs/architecture.md) | Detailed system architecture and data flow |
| [Compliance](docs/compliance.md) | Compliance controls and audit evidence |
| [KEDA vs HPA](docs/keda-vs-hpa.md) | Autoscaling strategy decision guide |
| [Operations Runbook](docs/runbook.md) | Day-2 operations, troubleshooting, and incident response |

## 🏷️ Technology Stack

| Layer | Technology |
|---|---|
| **Cloud** | AWS (EKS, Aurora, SQS, SNS, KMS, WAF, CloudTrail) |
| **Orchestration** | Kubernetes 1.31, Karpenter 1.1 |
| **Service Mesh** | Istio (STRICT mTLS) |
| **Autoscaling** | KEDA (event-driven) + Native HPA (scale-to-zero) |
| **GitOps** | ArgoCD (app-of-apps, sync waves) |
| **Logging** | FluentBit → CloudWatch (PII masking) |
| **IaC** | Terraform 1.9 (modular, multi-env) |
| **CI/CD** | GitHub Actions (security scanning, matrix builds) |
| **Runtime** | Python 3.12, FastAPI, Distroless containers |
| **Security** | tfsec, checkov, Trivy, kubeconform, kubesec |

## License

Proprietary — Internal use only.
