# 3-Tier DevOps Quiz Application on AWS EKS

**Author: Pushparaj Naik**

Production-ready 3-tier application deployed on AWS EKS with **GitOps** (ArgoCD), featuring a React frontend, Flask backend, and PostgreSQL (RDS) database. Infrastructure is fully managed via Terraform with self-healing, automated drift detection.

## Architecture

| Layer | Technology | Description |
|-------|-----------|-------------|
| **Frontend** | React 18, Tailwind CSS, Nginx | Interactive quiz UI served via Nginx |
| **Backend** | Flask, Gunicorn, SQLAlchemy | REST API with quiz/topic CRUD |
| **Database** | AWS RDS PostgreSQL 14 | Encrypted, Multi-AZ (prod) with automated backups |
| **Orchestration** | AWS EKS 1.31 | Managed Kubernetes with HPA and PDB |
| **GitOps** | ArgoCD (Helm) | App-of-Apps pattern, drift detection, self-healing |
| **Secrets** | External Secrets Operator | AWS Secrets Manager → K8s secrets (no base64 in Git) |
| **Networking** | ALB, Route53, ACM | HTTPS ingress with WAF protection |
| **Monitoring** | Prometheus + Grafana | Full observability stack via Helm |
| **Security** | KMS, Secrets Manager, IRSA | Encryption at rest/transit, OIDC auth |
| **Compliance** | CloudTrail, GuardDuty, Config | GDPR/SOC2/EU-USA regulatory compliance |
| **State** | S3 + DynamoDB | Remote Terraform state with locking |
| **CI/CD** | GitHub Actions + OIDC | GitOps pipeline — builds images, commits tags, ArgoCD syncs |
| **DR** | Cross-region snapshots, Multi-AZ | RPO < 1hr, RTO < 4hr |

## GitOps Workflow

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  Developer   │────▶│   GitHub     │────▶│  GitHub      │────▶│   ArgoCD     │
│  git push    │     │  Repository  │     │  Actions CI  │     │  (on EKS)    │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
                                                │                      │
                                                ▼                      ▼
                                          Build Docker           Detect Git
                                          Push to ECR            changes in
                                          Update image           k8s/ manifests
                                          tags in Git            Auto-sync to
                                                                 EKS cluster
                                                                      │
                                                                      ▼
                                                              ┌──────────────┐
                                                              │  Self-Heal   │
                                                              │  if drift    │
                                                              │  detected    │
                                                              └──────────────┘
```

**Key principle:** The CI pipeline **never** runs `kubectl apply`. It only updates image tags in Git. ArgoCD detects the commit and reconciles the cluster state.

## Prerequisites

- AWS CLI v2 configured
- Terraform >= 1.5
- kubectl
- Helm 3
- Docker
- Node.js 20+ (for local frontend dev)

## Quick Start — Local Development

```bash
# Clone and start locally
docker-compose up --build

# Access:
# Frontend: http://localhost:3000
# Backend API: http://localhost:8000/api
```

## Production Deployment

### 1. Infrastructure (Terraform)

```bash
cd infra
terraform init
terraform plan -out=plan.out
terraform apply plan.out
```

This provisions:
- ✅ EKS cluster with EBS CSI driver
- ✅ RDS PostgreSQL with encryption
- ✅ ArgoCD via Helm (App-of-Apps pattern)
- ✅ External Secrets Operator (IRSA)
- ✅ S3 + DynamoDB for remote state
- ✅ CloudTrail, GuardDuty, KMS

### 2. Configure kubectl

```bash
aws eks update-kubeconfig --name pushparaj-dev-cluster --region ap-south-1
```

### 3. Access ArgoCD

```bash
# Port-forward to ArgoCD server
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d

# Open: https://localhost:8080
# Login: admin / <password from above>
```

### 4. Verify GitOps Sync

After ArgoCD is running, it automatically deploys all applications from the `argocd/apps/` directory:

| ArgoCD App | Manages | Source Path |
|---|---|---|
| `3tier-app-of-apps` | Parent (all children) | `argocd/apps/` |
| `frontend` | Frontend Deployment + Ingress | `k8s/frontend.yaml` |
| `backend` | Backend Deployment + ConfigMap | `k8s/backend.yaml` |
| `platform` | Namespace, RBAC, HPA, PDB, etc. | `k8s/*.yaml` |

```bash
# Verify all apps are synced
kubectl get applications -n argocd
```

### 5. Test Drift Detection (Self-Healing)

```bash
# Manually change something
kubectl scale deployment/backend --replicas=1 -n 3-tier-app-eks

# Watch ArgoCD revert it back to the desired state (2 replicas)
kubectl get pods -n 3-tier-app-eks -w
```

### 6. Setup Monitoring (Optional)

```bash
chmod +x k8s/setup-monitoring.sh
./k8s/setup-monitoring.sh
```

## Remote State Migration

After the initial `terraform apply` (which creates the S3 bucket and DynamoDB table):

```bash
# 1. Uncomment the backend "s3" block in providers.tf
# 2. Re-initialize with state migration
terraform init -migrate-state
```

## Project Structure

```
3Tier_EKS_React/
├── .github/workflows/
│   └── gitops-ci.yml          # GitOps CI/CD pipeline
├── argocd/
│   ├── app-of-apps.yaml       # Parent ArgoCD Application
│   ├── apps/
│   │   ├── frontend.yaml      # Child: frontend
│   │   ├── backend.yaml       # Child: backend
│   │   └── platform.yaml      # Child: shared resources
│   └── values/
│       └── argocd-values.yaml  # Helm values reference
├── backend/                    # Flask REST API
├── frontend/                   # React SPA
├── infra/
│   ├── argocd.tf              # ArgoCD Helm release
│   ├── argocd_apps.tf         # App-of-Apps bootstrap
│   ├── compliance.tf          # CloudTrail, GuardDuty
│   ├── dr.tf                  # Disaster Recovery
│   ├── eks.tf                 # EKS cluster + addons
│   ├── external_secrets.tf    # ESO + IRSA
│   ├── network.tf             # VPC module
│   ├── providers.tf           # AWS, Helm, K8s providers
│   ├── rds.tf                 # PostgreSQL RDS
│   ├── state.tf               # S3 + DynamoDB for remote state
│   ├── variables.tf           # Core variables
│   └── variables_argocd.tf    # GitOps variables
├── k8s/
│   ├── backend.yaml           # Backend Deployment + Service
│   ├── frontend.yaml          # Frontend Deployment + Service
│   ├── external-secret.yaml   # AWS SM → K8s secrets (replaces secrets.yaml)
│   ├── hpa.yaml               # Horizontal Pod Autoscaler
│   ├── pdb.yaml               # Pod Disruption Budgets
│   ├── network-policies.yaml  # Network segmentation
│   └── ...
└── docs/
    ├── ARCHITECTURE.md
    └── RUNBOOK.md
```

## License

MIT License - Pushparaj Naik
