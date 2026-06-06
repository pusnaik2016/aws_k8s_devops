# Multi-Region 3-Tier EKS DevSecOps Infrastructure

Production-grade, multi-region AWS infrastructure for a Java ecommerce application on private EKS clusters with Aurora Global Database, full DevSecOps CI/CD, and comprehensive security controls.

## Architecture Overview

```
                    ┌──────────────────────────────────────────────────────┐
                    │                    Route53 (Failover)                │
                    └─────────────┬────────────────────┬───────────────────┘
                                  │                    │
                    ┌─────────────▼──────────┐  ┌──────▼──────────────────┐
                    │   us-east-1 (Primary)  │  │  ap-south-1 (Secondary) │
                    │                        │  │                         │
                    │  ┌──────────────────┐  │  │  ┌──────────────────┐   │
                    │  │   WAF → ALB      │  │  │  │   WAF → ALB      │   │
                    │  └────────┬─────────┘  │  │  └────────┬─────────┘   │
                    │           │             │  │           │             │
                    │  ┌────────▼─────────┐  │  │  ┌────────▼─────────┐   │
                    │  │  Private EKS     │  │  │  │  Private EKS     │   │
                    │  │  ┌─────────────┐ │  │  │  │  ┌─────────────┐ │   │
                    │  │  │ Java App    │ │  │  │  │  │ Java App    │ │   │
                    │  │  │ HPA+Karpent │ │  │  │  │  │ HPA+Karpent │ │   │
                    │  │  └─────────────┘ │  │  │  │  └─────────────┘ │   │
                    │  └────────┬─────────┘  │  │  └────────┬─────────┘   │
                    │           │             │  │           │             │
                    │  ┌────────▼─────────┐  │  │  ┌────────▼─────────┐   │
                    │  │ Aurora (Writer)  │◄─┼──┼──│ Aurora (Reader)  │   │
                    │  └─────────────────┘  │  │  └──────────────────┘   │
                    └────────────────────────┘  └─────────────────────────┘
```

## Key Features

| Feature | Implementation |
|---------|---------------|
| **Multi-Region** | us-east-1 (primary) + ap-south-1 (DR) |
| **Compute** | Private EKS clusters with Karpenter autoscaling |
| **Database** | Aurora Global Database (cross-region replication, <1s RPO) |
| **Autoscaling** | HPA (CPU+memory) + Karpenter (right-sized nodes) |
| **Encryption** | KMS CMK for EKS, EBS, Aurora, CloudWatch, S3, SNS, SQS |
| **CI/CD** | GitHub Actions: Terraform IaC + Java App CI + Helm CD |
| **Security Scanning** | Gitleaks, SonarCloud, OWASP DC, Trivy, Checkov |
| **Monitoring** | CloudWatch, GuardDuty, Security Hub, AWS Config |
| **Networking** | Private subnets, VPC Endpoints, VPC Flow Logs |
| **Compliance** | PCI DSS, HIPAA, SOC 2 aligned controls |

## Project Structure

```
├── terraform/
│   ├── modules/           # Reusable modules (vpc, eks, kms, sg, cw, s3)
│   └── environments/
│       ├── primary/       # us-east-1 configuration
│       └── secondary/     # ap-south-1 configuration
├── helm/
│   ├── ecommerce-app/     # Application Helm chart
│   └── karpenter/         # Karpenter NodePool config
├── k8s-manifests/         # NetworkPolicies, PodSecurity, Quotas
└── .github/workflows/     # CI/CD pipelines
```

## Quick Start

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform >= 1.5.0
- kubectl, helm installed
- GitHub repository with OIDC configured

### Deploy Primary Region
```bash
cd terraform/environments/primary
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform plan
terraform apply
```

### Deploy Secondary Region
```bash
cd terraform/environments/secondary
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

### Deploy Application
```bash
# Via GitHub Actions (recommended) or manually:
helm upgrade --install ecommerce-app helm/ecommerce-app \
  --namespace ecommerce --create-namespace \
  --values helm/ecommerce-app/values.yaml \
  --values helm/ecommerce-app/values-us-east-1.yaml \
  --set image.repository=<ECR_URL> \
  --set image.tag=<TAG>
```

## GitHub Secrets Required

| Secret | Description |
|--------|-------------|
| `AWS_ACCOUNT_ID` | AWS account ID |
| `SONAR_TOKEN` | SonarCloud authentication token |
| `SONAR_ORGANIZATION` | SonarCloud organization |

## Well-Architected Alignment

- **Reliability**: Multi-region EKS + Aurora Global DB + Route53 failover
- **Security**: KMS CMK encryption, least-privilege IAM, GuardDuty, Security Hub
- **Performance**: HPA + Karpenter autoscaling, Aurora read replicas
- **Operational Excellence**: Fully automated DevSecOps pipelines
- **Cost Optimization**: Karpenter spot instances, S3 lifecycle policies
