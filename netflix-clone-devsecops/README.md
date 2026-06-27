# 🎬 Netflix Clone — DevSecOps Pipeline on AWS EKS

A production-grade Netflix Clone application deployed on AWS EKS with a full **DevSecOps pipeline** powered by **GitHub Actions**, replacing Jenkins from the original architecture.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  Developer → GitHub Push → GitHub Actions CI (10 stages)                   │
│                  │                                                          │
│                  ├── Gitleaks (secrets scan)                                │
│                  ├── SonarCloud (SAST)                                      │
│                  ├── npm audit (SCA)                                        │
│                  ├── React Build                                            │
│                  ├── Docker Build (multi-stage Nginx)                       │
│                  ├── Trivy (container scan)                                 │
│                  └── Push to ECR (via OIDC — keyless)                      │
│                         │                                                   │
│                         ▼                                                   │
│               GitHub Actions CD → Update k8s-manifests repo                │
│                         │                                                   │
│                         ▼                                                   │
│  ┌── AWS VPC (10.0.0.0/16) ──────────────────────────────────────────┐     │
│  │                                                                    │     │
│  │  Public Subnets:  ALB + NAT + Bastion                             │     │
│  │  Private Subnets: EKS Cluster (private API endpoint)              │     │
│  │                                                                    │     │
│  │  ArgoCD (in EKS) ← watches Git → auto-syncs deployment           │     │
│  │                                                                    │     │
│  │  Monitoring: Prometheus + Grafana (Helm in EKS)                   │     │
│  │                                                                    │     │
│  └────────────────────────────────────────────────────────────────────┘     │
│                                                                             │
│  Edge Security: Route53 → WAF v2 → ALB (HTTPS/TLS 1.3) → Pods            │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

| Tool | Purpose |
|:-----|:--------|
| [Terraform](https://terraform.io) ≥ 1.5 | Infrastructure as Code |
| [AWS CLI](https://aws.amazon.com/cli/) v2 | AWS resource management |
| [Docker](https://docker.com) | Local container builds |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | Kubernetes management |
| [TMDB API Key](https://www.themoviedb.org/settings/api) | Movie data for the app |

### Step 1: Clone & Configure

```bash
git clone https://github.com/your-org/netflix-clone-devsecops.git
cd netflix-clone-devsecops/terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### Step 2: Deploy Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

### Step 3: Configure GitHub Secrets

After `terraform apply`, configure these GitHub secrets (shown in outputs):

| Secret | Value |
|:-------|:------|
| `AWS_ACCOUNT_ID` | Your AWS account ID |
| `SONAR_TOKEN` | SonarCloud authentication token |
| `SONAR_ORGANIZATION` | SonarCloud organization key |
| `TMDB_API_KEY` | TMDB API key |
| `MANIFEST_REPO_TOKEN` | GitHub PAT with repo write access |

### Step 4: Bootstrap ArgoCD

```bash
# SSH into bastion
ssh -i ~/.ssh/devsecops-key.pem ubuntu@<BASTION_IP>

# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name netflix-devsecops-eks

# Apply ArgoCD application
kubectl apply -f argocd/application.yaml -n argocd

# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Step 5: Push Code → Automatic Deployment

```bash
git push origin main
# CI pipeline runs automatically → builds → scans → pushes to ECR → ArgoCD deploys
```

## 🛡️ Security Stack (12 Layers)

| # | Layer | Component |
|:--|:------|:----------|
| 1 | Edge | Route53 + ACM (HTTPS/TLS 1.3) |
| 2 | Firewall | WAF v2 (OWASP Top 10, SQLi, rate limiting) |
| 3 | API | API Gateway (JWT auth, throttling) |
| 4 | Auth | Cognito (user pools, MFA) |
| 5 | Transport | ALB + VPC Link (private connectivity) |
| 6 | Network | Private subnets (no public IPs on nodes) |
| 7 | Cluster | EKS Private API (kubectl only from VPC) |
| 8 | Node | IMDSv2 (blocks SSRF credential theft) |
| 9 | Secrets | KMS (K8s secrets encrypted at rest) |
| 10 | Pod | Non-root Nginx (UID 101) |
| 11 | CI/CD | GitHub OIDC (keyless AWS auth) |
| 12 | Code | SonarCloud + Trivy + Gitleaks |

## 📊 Monitoring

- **Prometheus**: Metrics collection (7-day retention)
- **Grafana**: Pre-configured dashboards (K8s cluster + pods)
- **CloudWatch**: AWS-level alarms (IAM changes, root login, WAF blocks)
- **DORA Metrics**: Automated weekly reports (deployment frequency, lead time, change failure rate)

Access from bastion:
```bash
# Grafana
kubectl port-forward -n monitoring svc/grafana 3000:80
# Open http://localhost:3000 (admin / DevSecOps2024!)

# Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

## 💰 Cost Estimate

| Resource | Monthly Cost |
|:---------|:-------------|
| EKS Cluster | ~$73 |
| EC2 Nodes (2× t3.medium) | ~$60 |
| NAT Gateway (single) | ~$32 |
| ALB | ~$16 |
| VPC Endpoints (6) | ~$36 |
| Bastion (t3.micro) | ~$8 |
| Misc (S3, CW, ECR) | ~$10 |
| **Total** | **~$235/month** |

## 📁 Project Structure

```
netflix-clone-devsecops/
├── app/                          # React Netflix Clone
│   ├── src/                      # React source code
│   ├── public/                   # Static assets
│   ├── Dockerfile                # Multi-stage build (Node → Nginx)
│   └── nginx.conf                # Production Nginx config
├── .github/workflows/            # GitHub Actions CI/CD
│   ├── ci.yml                    # 10-stage CI pipeline
│   ├── cd.yml                    # GitOps CD pipeline
│   ├── compliance-check.yml      # PCI/HIPAA/SOC2 compliance
│   └── dora-report.yml           # DORA metrics report
├── terraform/                    # AWS Infrastructure as Code
│   ├── provider.tf               # Providers
│   ├── variables.tf              # Input variables
│   ├── vpc.tf                    # VPC + subnets + endpoints
│   ├── security-groups.tf        # Firewall rules
│   ├── eks.tf                    # EKS private cluster
│   ├── eks-iam.tf                # IAM roles (IRSA)
│   ├── eks-addons.tf             # ALB Controller + ArgoCD + Prometheus + Grafana
│   ├── ecr.tf                    # Container registry
│   ├── alb.tf                    # Load balancer
│   ├── waf.tf                    # Web Application Firewall
│   ├── github-oidc.tf            # OIDC federation
│   ├── route53.tf                # DNS + TLS certs
│   ├── cognito.tf                # User authentication
│   ├── api-gateway.tf            # API management
│   ├── cloudtrail.tf             # Audit logging
│   ├── monitoring.tf             # CloudWatch alarms
│   └── outputs.tf                # Resource outputs
├── k8s-manifests/                # Kubernetes resources
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ingress.yaml
├── argocd/                       # GitOps configuration
│   └── application.yaml
└── docs/                         # Documentation
    ├── architecture.md
    └── runbook.md
```

## 📜 License

This project is for educational and demonstration purposes. Not affiliated with Netflix.
Powered by [TMDB API](https://www.themoviedb.org/).
