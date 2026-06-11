# 🏥 MedCloud Global Platform

> **Multi-Cloud Healthcare & Medical E-Commerce Platform** — A production-grade, HIPAA/GDPR/PCI-DSS compliant system spanning AWS, Azure, and GCP with advanced DevSecOps, AI/ML, and zero-trust security.

---

## 🏗️ Architecture Overview

```
                    ┌─────────────────────────────────┐
                    │     Global DNS (Route 53)        │
                    │     + CloudFront / Front Door     │
                    │     + Cloud CDN                   │
                    └──────────┬──────────────────────┘
                               │
          ┌────────────────────┼────────────────────┐
          ▼                    ▼                     ▼
   ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
   │     AWS      │◄──►│    AZURE     │◄──►│     GCP      │
   │  Core App &  │    │  AI & Medical│    │  Analytics & │
   │  E-Commerce  │    │   Imaging    │    │    ML Ops    │
   │              │    │              │    │              │
   │ ┌──────────┐ │    │ ┌──────────┐ │    │ ┌──────────┐ │
   │ │   EKS    │ │    │ │   AKS    │ │    │ │   GKE    │ │
   │ │ Cluster  │ │    │ │ Cluster  │ │    │ │ Cluster  │ │
   │ └──────────┘ │    │ └──────────┘ │    │ └──────────┘ │
   │ ┌──────────┐ │    │ ┌──────────┐ │    │ ┌──────────┐ │
   │ │ Aurora   │ │    │ │ Cosmos DB│ │    │ │ BigQuery │ │
   │ │ Global   │ │    │ │ + Azure  │ │    │ │ + Vertex │ │
   │ │ Database │ │    │ │ OpenAI   │ │    │ │ AI       │ │
   │ └──────────┘ │    │ └──────────┘ │    │ └──────────┘ │
   └──────────────┘    └──────────────┘    └──────────────┘
          │                    │                     │
          └────────────────────┼─────────────────────┘
                    Istio Service Mesh (mTLS)
                    + Cross-Cloud VPN/Peering
```

## ☁️ Cloud Provider Roles

| Cloud | Role | Key Services |
|-------|------|-------------|
| **AWS** | Core Application & E-Commerce Hub | EKS, Aurora Global DB, DynamoDB, ElastiCache, S3, CloudFront, Route 53, KMS |
| **Azure** | Enterprise Medical & AI Hub | AKS, Cosmos DB, Azure OpenAI, Azure AI Vision, Blob Storage, Key Vault, Front Door |
| **GCP** | Big Data & Global Analytics Engine | GKE, BigQuery, Vertex AI, Cloud Bigtable, Cloud Storage, Cloud DLP, Cloud CDN |

## 🏗️ Microservices

| Service | Cloud | Language/Framework | Purpose |
|---------|-------|--------------------|---------|
| **storefront-api** | AWS EKS | Java 21 / Spring Boot 3.3 | E-commerce API, product catalog, search |
| **order-service** | AWS EKS | Java 21 / Spring Boot 3.3 | Order processing, payment orchestration |
| **patient-service** | Azure AKS | Java 21 / Spring Boot 3.3 | Patient profiles, consent, EHR integration |
| **imaging-service** | Azure AKS | Python 3.12 / FastAPI | DICOM image processing, AI Vision |
| **ai-gateway** | GCP GKE | Python 3.12 / FastAPI | ML inference, fraud detection |
| **notification-service** | AWS EKS | Java 21 / Spring Boot 3.3 | Multi-channel alerts (SNS/SES) |

## 📁 Project Structure

```
medcloud-global-platform/
├── .github/workflows/                      # CI/CD Pipelines (3 workflows)
│   ├── medcloud-infra.yml                  #   Terraform: tfsec/Checkov → Plan → Apply
│   ├── medcloud-app-build.yml              #   App: Maven/pytest → SonarQube → Docker → Trivy → Deploy
│   └── medcloud-security-scan.yml          #   Nightly: container drift + compliance + DAST
├── apps/                                   # Application Source & Dockerfiles
│   ├── storefront-api/                     #   Dockerfile + pom.xml (Spring Boot 3.3)
│   ├── order-service/                      #   Dockerfile (Java 21)
│   ├── patient-service/                    #   Dockerfile (Java 21)
│   ├── imaging-service/                    #   Dockerfile (Python 3.12 / FastAPI)
│   ├── ai-gateway/                         #   Dockerfile (Python 3.12 / FastAPI)
│   └── notification-service/               #   Dockerfile (Java 21)
├── terraform/
│   ├── aws/                                # AWS Infrastructure
│   │   ├── networking/                     #   VPC, subnets, Transit Gateway
│   │   ├── eks/                            #   EKS cluster, managed node groups
│   │   ├── databases/                      #   Aurora PostgreSQL, DynamoDB, ElastiCache
│   │   ├── storage/                        #   S3 buckets, CloudFront distributions
│   │   ├── security/                       #   KMS, WAF, Shield Advanced, GuardDuty
│   │   └── monitoring/                     #   CloudWatch dashboards, X-Ray
│   ├── azure/                              # Azure Infrastructure
│   │   ├── networking/                     #   VNet, subnets, VPN Gateway, Azure Firewall
│   │   ├── aks/                            #   AKS cluster, node pools
│   │   ├── databases/                      #   Cosmos DB, Azure SQL
│   │   ├── storage/                        #   Blob Storage (DICOM images, EHR docs)
│   │   ├── ai-services/                    #   Azure OpenAI, AI Vision, AI Search
│   │   └── security/                       #   Key Vault, Defender, Sentinel
│   ├── gcp/                                # GCP Infrastructure
│   │   ├── networking/                     #   VPC, Cloud Router, HA VPN
│   │   ├── gke/                            #   GKE cluster, Workload Identity
│   │   ├── databases/                      #   Cloud SQL, Bigtable
│   │   ├── storage/                        #   Cloud Storage (data lake)
│   │   ├── analytics/                      #   BigQuery, Dataflow, Pub/Sub
│   │   └── ml-platform/                    #   Vertex AI, Feature Store
│   ├── modules/                            # Reusable Cross-Cloud Modules
│   │   ├── vpc/                            #   Networking module
│   │   ├── kubernetes/                     #   K8s cluster module
│   │   ├── database/                       #   Database module
│   │   ├── security/                       #   Security baseline module
│   │   └── observability/                  #   Monitoring module
│   ├── environments/                       # Per-Environment Configuration
│   │   ├── dev/                            #   main.tf + backend.hcl + terraform.tfvars
│   │   ├── staging/                        #   main.tf + backend.hcl + terraform.tfvars
│   │   └── prod/                           #   main.tf + backend.hcl + terraform.tfvars
│   ├── variables.tf                        # Global variable definitions
│   └── versions.tf                         # Provider version constraints
├── kubernetes/
│   ├── base/                               # Cluster-Wide Resources
│   │   ├── namespaces/                     #   Namespace definitions
│   │   ├── network-policies/               #   Zero-trust network policies
│   │   └── rbac/                           #   Role-based access control
│   ├── apps/                               # Application K8s Manifests
│   │   ├── storefront-api/                 #   Deployment + Service (AWS EKS)
│   │   ├── patient-service/                #   Deployment + Service (Azure AKS)
│   │   ├── order-service/                  #   Deployment + Service (AWS EKS)
│   │   ├── imaging-service/                #   Deployment + Service (Azure AKS)
│   │   ├── ai-gateway/                     #   Deployment + Service (GCP GKE)
│   │   └── notification-service/           #   Deployment + Service (AWS EKS)
│   ├── istio/                              # Service Mesh Configuration
│   │   ├── base/                           #   Istio operator install (multi-primary)
│   │   ├── policies/                       #   PeerAuth (mTLS STRICT), AuthorizationPolicy
│   │   └── gateways/                       #   Ingress + East-West gateways
│   └── argocd/                             # GitOps Deployment
│       ├── applications/                   #   ArgoCD Application CRDs
│       └── projects/                       #   ArgoCD multi-cluster project
├── scripts/                                # Automation Scripts
│   ├── health-check.sh                     #   Cross-cloud daily health checks
│   ├── setup-backends.sh                   #   Terraform state backend init (S3/Azure SA/GCS)
│   └── rotate-secrets.sh                   #   Cross-cloud secret rotation
├── docs/                                   # Documentation
│   ├── architecture/                       #   Architecture + Design Details
│   ├── runbooks/                           #   Operations Runbook
│   └── compliance/                         #   HIPAA/GDPR/PCI-DSS Compliance Framework
├── .gitignore                              # Terraform state, IDE, secrets exclusions
└── README.md                               # This file
```

## 🔐 Compliance & Security

| Standard | Scope | Implementation |
|----------|-------|---------------|
| **HIPAA** | PHI data (patient records, medical images) | Encryption at rest (CMK), audit logging, BAA, access controls, non-root containers |
| **GDPR** | EU patient data | Data residency, right to erasure, consent management, DPO |
| **PCI-DSS** | Payment card data (e-commerce) | Network segmentation, WAF, encryption, tokenization, container scanning |

## 🚀 Quick Start

```bash
# 1. Initialize Terraform state backends
./scripts/setup-backends.sh dev

# 2. Deploy infrastructure
cd terraform/environments/dev
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars

# 3. Configure kubectl
aws eks update-kubeconfig --name medcloud-dev-eks --region us-east-1
az aks get-credentials --resource-group medcloud-dev-aks-rg --name medcloud-dev-aks
gcloud container clusters get-credentials medcloud-dev-gke --region us-central1

# 4. Deploy applications via ArgoCD
kubectl apply -f kubernetes/argocd/projects/medcloud-project.yaml
kubectl apply -f kubernetes/argocd/applications/medcloud-apps.yaml

# 5. Verify health
./scripts/health-check.sh
```

## 🔄 CI/CD Pipelines

| Pipeline | Workflow File | Trigger | Key Steps |
|----------|--------------|---------|-----------|
| **Infrastructure** | `medcloud-infra.yml` | `terraform/**` changes | tfsec → Checkov → Plan → Apply |
| **Application** | `medcloud-app-build.yml` | `apps/**` changes | Maven/pytest → SonarQube → Docker → Trivy → ArgoCD |
| **Security** | `medcloud-security-scan.yml` | Nightly (02:00 UTC) | Container drift → Compliance audit → ZAP DAST |

## 🛠️ Tech Stack

| Category | Technology |
|----------|-----------|
| **IaC** | Terraform (AWS + Azure + GCP providers) |
| **Application** | Java 21 / Spring Boot 3.3 (4 services), Python 3.12 / FastAPI (2 services) |
| **Build** | Maven (JaCoCo 70% min coverage), Docker multi-stage builds |
| **CI/CD** | GitHub Actions (3 workflows) + ArgoCD (GitOps) |
| **Containers** | Docker → Kubernetes (EKS / AKS / GKE) |
| **Service Mesh** | Istio (multi-cluster, multi-primary, mTLS STRICT) |
| **Monitoring** | Prometheus + Grafana + Cloud-native (CloudWatch / Monitor / Cloud Monitoring) |
| **Security** | tfsec, Checkov, SonarQube, OWASP Dependency Check, Trivy, ZAP |
| **Secrets** | AWS Secrets Manager + Azure Key Vault + GCP Secret Manager |
| **Registries** | AWS ECR, Azure ACR, GCP Artifact Registry |

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/architecture/ARCHITECTURE.md) | System context, ADRs, network topology, data flow, security layers, CI/CD pipelines, DR strategy |
| [Design Details](docs/architecture/DESIGN_DETAILS.md) | Microservices design, database schemas, API patterns, Istio mesh, AI/ML pipeline, container build strategy, FinOps |
| [Operations Runbook](docs/runbooks/OPERATIONS_RUNBOOK.md) | Cluster access, health checks, deployment procedures, incident response, scaling, scripts, troubleshooting |
| [Compliance Framework](docs/compliance/COMPLIANCE_FRAMEWORK.md) | HIPAA/GDPR/PCI-DSS control mapping, data classification, CI/CD compliance enforcement, audit trail |

## 📊 Project Statistics

| Category | Count | Details |
|----------|-------|---------|
| **Application Source** | 55 files | 4 Java services (Spring Boot 3.3): Controller → Service → Repository → Entity + tests |
| | | 2 Python services (FastAPI): Routes → Config → Tests |
| | | 4 `pom.xml` + 2 `requirements.txt` + 6 Dockerfiles + 4 `application.yml` |
| **Terraform Configs** | 28 files | 6 AWS + 6 Azure + 6 GCP + 5 modules + 2 root + 3 env configs |
| **K8s Manifests** | 14 files | 6 app deployments, 3 Istio configs, 3 base policies, 2 ArgoCD |
| **CI/CD Pipelines** | 3 workflows | Infrastructure, Application Build, Security Scanning |
| **Scripts** | 3 files | Health check, backend setup, secret rotation |
| **Documentation** | 5 files | Architecture, Design, Operations, Compliance, README |
| **Environments** | 3 | Dev (cost-optimized), Staging (pre-prod), Prod (HA) |
| **Cloud Providers** | 3 | AWS (6 modules), Azure (6 modules), GCP (6 modules) |
| **Total Files** | **115** | **~14,400+ lines of production-grade code** |

---

**Author:** Pushparaj Naik | **Version:** 2.0 | Multi-Cloud Healthcare Platform

