# 🔐 Automated DevSecOps Pipeline — Production Architecture

> **End-to-end CI/CD pipeline** using GitHub Actions, private EKS, ArgoCD GitOps, WAF, API Gateway, and Cognito — fully automated with Terraform.

[![GitHub Actions](https://img.shields.io/badge/CI/CD-GitHub_Actions-2088FF?style=for-the-badge&logo=github-actions&logoColor=white)](https://github.com/features/actions)
[![EKS](https://img.shields.io/badge/Kubernetes-Amazon_EKS-FF9900?style=for-the-badge&logo=amazon-eks&logoColor=white)](https://aws.amazon.com/eks/)
[![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-EF7B4D?style=for-the-badge&logo=argo&logoColor=white)](https://argoproj.github.io/cd/)
[![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![WAF](https://img.shields.io/badge/Security-AWS_WAF-232F3E?style=for-the-badge&logo=amazon-aws&logoColor=white)](https://aws.amazon.com/waf/)
[![SonarCloud](https://img.shields.io/badge/SAST-SonarCloud-F3702A?style=for-the-badge&logo=sonarcloud&logoColor=white)](https://sonarcloud.io/)

---

## 🎯 What This Project Does

Pushes code to GitHub → automatically builds, tests, scans for security → pushes container image to ECR → updates Kubernetes manifests → ArgoCD deploys to a private EKS cluster — all with zero manual intervention.

```
Developer → GitHub → GitHub Actions CI (12 stages) → ECR
                   → GitHub Actions CD (manifest update) → ArgoCD → Private EKS
```

### Security Stack

```
Client → Route53 → WAF (OWASP rules) → API Gateway (Cognito JWT) → ALB → EKS Pod
```

---

## 🏗 Architecture

```
┌─────────────────────────── AWS VPC (10.0.0.0/16) ──────────────────────────────┐
│                                                                                 │
│  ┌─── Public Subnets (3 AZs) ──────────────────────────────────────────────┐   │
│  │  10.0.1.0/24 (AZ-a)  │  10.0.2.0/24 (AZ-b)  │  10.0.3.0/24 (AZ-c)    │   │
│  │  • ALB               │  • ALB                │  • ALB                  │   │
│  │  • NAT Gateway       │                       │                         │   │
│  │  • Bastion (t3.micro)│                       │                         │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  ┌─── Private Subnets (3 AZs) ── EKS PRIVATE CLUSTER ──────────────────────┐   │
│  │  10.0.101.0/24 (AZ-a)│  10.0.102.0/24 (AZ-b)│  10.0.103.0/24 (AZ-c)   │   │
│  │  • EKS Node          │  • EKS Node           │  • EKS Node             │   │
│  │  • App Pods          │  • App Pods            │  • ArgoCD               │   │
│  │  • ALB Controller    │                        │                         │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  ┌─── VPC Endpoints (PrivateLink) ──────────────────────────────────────────┐   │
│  │  ECR API │ ECR DKR │ S3 (Free) │ STS │ CloudWatch Logs │ EKS API       │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  ┌─── Edge Security ───────────────────────────────────────────────────────┐    │
│  │  Route53 → WAF v2 → API Gateway (Cognito JWT) → ALB (HTTPS) → Pods    │    │
│  └──────────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────┘

          CI/CD: GitHub Actions (hosted runners — no EC2 needed)
          SAST:  SonarCloud (SaaS — no EC2 needed)
          Auth:  GitHub OIDC → AWS (keyless — no stored credentials)
```

> 📖 **[Architecture diagrams (11 Mermaid charts) →](docs/architecture.md)** | **[Operations Runbook →](docs/runbook.md)**

---

## 📁 Project Structure

```
Java_DevSecOps/
├── README.md                           # This file
├── .gitignore
│
├── .github/workflows/                  # 🔧 CI/CD Pipelines
│   ├── ci.yml                          # 12-stage CI (build, test, scan, push to ECR)
│   └── cd.yml                          # GitOps manifest update → ArgoCD auto-sync
│
├── terraform/                          # 🏗 Infrastructure as Code
│   ├── provider.tf                     # AWS + Kubernetes + Helm providers
│   ├── variables.tf                    # All configurable variables
│   ├── vpc.tf                          # Multi-AZ VPC + 6 VPC Endpoints
│   ├── security-groups.tf              # Bastion, ALB, EKS cluster/node SGs
│   ├── ec2-bastion.tf                  # Bastion host (kubectl access to private EKS)
│   ├── eks.tf                          # Private EKS cluster + managed node groups
│   ├── eks-iam.tf                      # IAM roles (cluster, nodes, IRSA for ALB)
│   ├── eks-addons.tf                   # Helm: ALB Controller + ArgoCD
│   ├── alb.tf                          # Application Load Balancer (HTTPS)
│   ├── api-gateway.tf                  # HTTP API v2 + VPC Link + Cognito auth
│   ├── waf.tf                          # WAF v2 Web ACL (OWASP + rate limiting)
│   ├── route53.tf                      # DNS + ACM wildcard certificate
│   ├── cognito.tf                      # User Pool + OAuth2 client + hosted UI
│   ├── ecr.tf                          # Container registry + lifecycle policy
│   ├── github-oidc.tf                  # OIDC provider for keyless GitHub→AWS auth
│   ├── outputs.tf                      # Resource outputs + setup instructions
│   └── terraform.tfvars.example        # Example variable values
│
├── app/                                # ☕ Java Application
│   ├── pom.xml                         # Maven config (JaCoCo, OWASP DC plugins)
│   ├── Dockerfile                      # Multi-stage build (non-root user)
│   └── src/                            # Spring Boot source code
│
├── k8s-manifests/                      # ☸️ Kubernetes Manifests (GitOps Repo)
│   ├── namespace.yaml                  # boardgame namespace
│   ├── deployment.yaml                 # Multi-AZ with topology spread
│   ├── service.yaml                    # ClusterIP (ALB handles external access)
│   └── ingress.yaml                    # ALB Ingress Controller integration
│
├── argocd/                             # 🔄 ArgoCD Application CR
│   └── application.yaml                # GitOps sync config (auto-heal + prune)
│
└── docs/                               # 📖 Documentation
    ├── architecture.md                 # 11 Mermaid diagrams (pipeline, infra, security)
    └── runbook.md                      # Comprehensive operations runbook
```

---

## 🚀 Quick Start

### Step 1: Provision Infrastructure

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values (GitHub org, domain, key pair)

terraform init
terraform plan
terraform apply
```

### Step 2: Configure GitHub Secrets

After `terraform apply`, get the output values and add them to your GitHub repository:

```bash
# Get the role ARN for OIDC
terraform output github_actions_role_arn

# Get all setup instructions
terraform output github_actions_setup
```

Add these **GitHub Secrets**:

| Secret | Value | Source |
|--------|-------|--------|
| `AWS_ACCOUNT_ID` | Your AWS account ID | `aws sts get-caller-identity` |
| `SONAR_TOKEN` | SonarCloud token | [sonarcloud.io](https://sonarcloud.io) → My Account → Security |
| `SONAR_ORGANIZATION` | SonarCloud org key | [sonarcloud.io](https://sonarcloud.io) → Organization Settings |
| `MANIFEST_REPO_TOKEN` | GitHub PAT | Settings → Developer Settings → PAT (repo write) |

### Step 3: Configure kubectl (from Bastion)

```bash
# SSH into bastion
ssh -i ~/.ssh/key.pem ubuntu@$(terraform output -raw bastion_public_ip)

# Configure kubectl for private EKS
aws eks update-kubeconfig --region us-east-1 --name java-devsecops-eks

# Verify cluster access
kubectl get nodes

# Deploy ArgoCD application
kubectl apply -f argocd/application.yaml
```

### Step 4: Push Code → Watch The Pipeline

```bash
git push origin main
# → GitHub Actions CI runs automatically (12 stages)
# → CD workflow updates manifest repo
# → ArgoCD deploys to EKS within ~3 minutes
```

### Step 5: Test Cognito Auth

```bash
# Get the hosted UI URL
terraform output cognito_hosted_ui_url

# Sign up, get JWT, call API
curl -H "Authorization: Bearer <JWT>" https://api.yourdomain.com/api/health
```

---

## 🛡️ Security Layers (Defense in Depth)

| Layer | Component | Protection |
|:------|:----------|:-----------|
| **1. Edge** | Route53 + ACM | HTTPS/TLS 1.3, domain validation |
| **2. Firewall** | WAF v2 | OWASP Top 10, SQLi, rate limiting, bad inputs |
| **3. API** | API Gateway | JWT authorization, request throttling |
| **4. Auth** | Cognito | User pools, MFA, token revocation |
| **5. Transport** | ALB + VPC Link | Private connectivity, health checks |
| **6. Network** | Private subnets | No public IPs on EKS nodes |
| **7. Cluster** | EKS Private API | kubectl only from VPC (bastion) |
| **8. Node** | IMDSv2 | Blocks SSRF credential theft |
| **9. Secrets** | KMS | Kubernetes secrets encrypted at rest |
| **10. Pod** | IRSA | Fine-grained IAM per service account |
| **11. CI/CD** | GitHub OIDC | Keyless AWS auth, no stored credentials |
| **12. Code** | SonarCloud + Trivy | SAST, SCA, container scanning |

---

## 💰 Monthly Cost Estimate

| Resource | Cost |
|:---------|:-----|
| EKS Control Plane | ~$73 |
| EKS Nodes (2× t3.medium) | ~$60 |
| NAT Gateway (1 shared) | ~$32 |
| ALB | ~$16 |
| VPC Endpoints (5 interface) | ~$36 |
| Bastion (t3.micro) | ~$8 |
| API Gateway + WAF + ECR | ~$10 |
| GitHub Actions | **Free** (2000 min/mo) |
| SonarCloud | **Free** (public repos) |
| **Total** | **~$235/month** |

> 💡 **$100/month saved** vs Jenkins architecture (no Jenkins EC2, no SonarQube EC2).
> Stop the bastion when not in use for additional savings.

---

## 🧹 Cleanup

```bash
cd terraform
terraform destroy
```

---

## 📄 License

Educational and demonstration purposes.
