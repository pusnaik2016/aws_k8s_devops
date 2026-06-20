# CLAUDE.md — Standing Brief for Claude DevOps Agent
# ====================================================
# This file is automatically loaded by Claude Code at every session start.
# It provides permanent context, rules, and guardrails for autonomous
# DevOps workflows across this repository.
#
# Author: Pushparaj Naik
# Last Updated: 2026-06-18

## Project Context

**HealthCloud Multi-Region DR** is a production-grade, HIPAA-compliant
healthcare platform with AWS as the primary region and Azure as the
disaster recovery (DR) region. It implements all Claude Code for DevOps
recommendations: autonomous agent workflows, custom slash commands,
quality-gate hooks, and zero-dependency Python automation engines.

### Architecture

- **Primary:** AWS us-east-1 (EKS, Aurora PostgreSQL, S3, CloudFront)
- **DR:** Azure eastus (AKS, Azure Database for PostgreSQL, Blob Storage)
- **Failover:** Route 53 health-check failover → Azure Traffic Manager
- **RPO:** < 15 minutes (async database replication)
- **RTO:** < 30 minutes (automated failover with pre-warmed DR)

### Technology Stack

| Layer             | Primary (AWS)                | DR (Azure)                    |
|-------------------|------------------------------|-------------------------------|
| **Compute**       | EKS 1.30 (Karpenter)        | AKS 1.30 (Cluster Autoscaler)|
| **Database**      | Aurora PostgreSQL 16 Global  | Azure DB for PostgreSQL Flex  |
| **Cache**         | ElastiCache Redis 7          | Azure Cache for Redis         |
| **Storage**       | S3 (SSE-KMS, Object Lock)   | Blob Storage (CMK, Immutable) |
| **Secrets**       | AWS Secrets Manager          | Azure Key Vault               |
| **DNS**           | Route 53 (failover routing)  | Azure Traffic Manager         |
| **CDN**           | CloudFront                   | Azure Front Door              |
| **WAF**           | AWS WAF v2                   | Azure WAF                     |
| **IaC**           | Terraform >= 1.5             | Terraform >= 1.5              |
| **CI/CD**         | GitHub Actions + ArgoCD      | GitHub Actions + ArgoCD       |
| **Service Mesh**  | Istio 1.22 (mTLS STRICT)    | Istio 1.22 (mTLS STRICT)     |
| **Monitoring**    | Prometheus + Grafana + X-Ray | Azure Monitor + Log Analytics |
| **Languages**     | Java 21, Python 3.12         | Java 21, Python 3.12          |

### Compliance

- **HIPAA** — PHI encrypted at rest and in transit, audit logging, BAA
- **GDPR** — Data residency, right to erasure, consent management
- **SOC 2** — Access controls, change management, incident response

---

## Hard Rules (NEVER VIOLATE)

### Security
1. **No hardcoded secrets** — Never embed AWS keys, database passwords, API
   tokens, or SSH private keys in source files. Use AWS Secrets Manager or
   Azure Key Vault via External Secrets Operator.
2. **No `:latest` Docker tags** — All container images MUST be pinned to a
   specific digest or semver tag (e.g., `python:3.12-slim@sha256:abc123`).
3. **No wide-open security groups** — Ingress rules MUST NOT use `0.0.0.0/0`
   for ports other than 80/443. Egress should be scoped where possible.
4. **HTTPS everywhere** — All external-facing endpoints must use TLS 1.3.
   No plain HTTP listeners in production.
5. **Least-privilege IAM** — Every IAM role/policy must follow least-privilege.
   No `Action: "*"` or `Resource: "*"` in production policies.
6. **PHI must be encrypted** — All Protected Health Information encrypted
   with customer-managed keys (CMK) at rest and TLS 1.3 in transit.
7. **No PHI in logs** — Structured logging only; PHI fields must be masked
   or tokenized before logging.

### Terraform
1. All resources MUST have at minimum these tags: `Environment`, `Project`,
   `ManagedBy`, `Owner`, `Compliance`, `DataClassification`.
2. Use `terraform fmt` formatting (canonical HCL style).
3. All modules MUST have `variables.tf`, `outputs.tf`, and `main.tf`.
4. Remote state MUST use S3 + DynamoDB locking (AWS) or Azure Storage Account (Azure).
5. Sensitive variables must use `sensitive = true`.
6. All encryption must use customer-managed keys (CMK), never AWS-managed.

### Kubernetes
1. All pods MUST have resource `requests` and `limits` defined.
2. All deployments MUST have `readinessProbe` and `livenessProbe`.
3. Containers MUST NOT run as root — use `securityContext.runAsNonRoot: true`.
4. Network policies MUST be defined for every namespace (default deny).
5. Use `PodDisruptionBudget` for all production workloads.
6. Images MUST come from approved registries only (ECR or ACR).
7. All pods MUST have `securityContext.readOnlyRootFilesystem: true`.

### Git & CI/CD
1. **Branch strategy**: `main` (production), `develop` (integration),
   `feature/*`, `hotfix/*`, `release/*`.
2. All commits to `main` require PR with at least 1 approval.
3. GitHub Actions workflows MUST include `permissions` blocks.
4. Use OIDC for AWS/Azure authentication — never store long-lived credentials.
5. All Docker images MUST pass Trivy scan with zero CRITICAL/HIGH before deploy.

### DR Specific
1. Database replication lag must be monitored and alerted (> 5 min = P2).
2. DR failover test MUST run monthly (automated via GitHub Actions).
3. Azure AKS must maintain minimum 2-node warm standby at all times.
4. Route 53 health checks must have < 30 second evaluation interval.

---

## Naming Conventions

| Resource Type      | Pattern                                | Example                           |
|--------------------|----------------------------------------|-----------------------------------|
| Terraform Module   | `kebab-case`                           | `dr-failover`                     |
| AWS Resource       | `{project}-{env}-{resource}`           | `healthcloud-prod-eks`            |
| Azure Resource     | `{project}-{env}-{resource}`           | `healthcloud-dr-aks`              |
| K8s Namespace      | `kebab-case`                           | `patient-service`                 |
| K8s Deployment     | `{app}-deployment`                     | `patient-service-deployment`      |
| K8s Service        | `{app}-service`                        | `patient-service-svc`             |
| Docker Image       | `{registry}/{project}/{app}:{semver}`  | `xxx.ecr.../healthcloud/patient:1.2.3` |
| Python Module      | `snake_case`                           | `sec_scanner.py`                  |
| Shell Script       | `kebab-case`                           | `health-check.sh`                 |
| GitHub Workflow    | `kebab-case`                           | `infra-ci-cd.yml`                 |

---

## Dangerous Commands — Require Explicit Approval

The following commands MUST NEVER be executed without explicit user
confirmation. The `hooks/pre-tool.sh` hook enforces this:

```
# Terraform
terraform apply
terraform destroy
terraform import
terraform state rm
terraform state mv

# Kubernetes
kubectl delete namespace
kubectl delete deployment
kubectl delete -f
kubectl drain
kubectl cordon

# AWS
aws iam delete-*
aws s3 rb
aws ec2 terminate-instances
aws rds delete-db-instance
aws rds delete-db-cluster
aws eks delete-cluster

# Azure
az group delete
az aks delete
az postgres server delete
az keyvault delete
az storage account delete

# System
rm -rf
git push --force
git reset --hard
docker system prune
docker volume prune
helm uninstall
helm delete
```

---

## File Structure Reference

```
healthcloud-multiregion-dr/
├── CLAUDE.md                          # THIS FILE — standing brief
├── README.md                          # Project documentation
├── .claude/commands/                  # Custom slash commands
├── hooks/                            # Quality gate hooks
├── scripts/devops/                   # Python automation engines
├── scripts/ops/                      # Operational scripts
├── apps/                             # Application Dockerfiles
├── terraform/aws/                    # AWS primary infrastructure
├── terraform/azure/                  # Azure DR infrastructure
├── terraform/modules/                # Reusable cross-cloud modules
├── terraform/environments/           # Per-env configuration
├── kubernetes/                       # K8s manifests (base, apps, istio, argocd)
├── .github/workflows/                # CI/CD pipelines
└── docs/                             # Architecture, runbooks, compliance
```

---

## Response Format Guidelines

When producing reports, always use this structured format:

```markdown
## 📋 Report: [Title]
**Scan Date:** YYYY-MM-DD HH:MM
**Scope:** [directories/files scanned]
**Compliance:** HIPAA | GDPR | SOC2

### ✅ Passed Checks
- [list of passed checks]

### ⚠️ Warnings
- [list of warnings with file:line references]

### ❌ Critical Findings
- [list of critical issues with file:line references]

### 🏥 HIPAA-Specific
- [PHI handling, encryption, audit trail findings]

### 📊 Summary
| Metric     | Value |
|------------|-------|
| Files      | N     |
| Passed     | N     |
| Warnings   | N     |
| Critical   | N     |

### Verdict: APPROVE / REQUEST CHANGES
[Reasoning]
```
