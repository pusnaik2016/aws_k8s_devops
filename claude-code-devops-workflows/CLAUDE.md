# CLAUDE.md — Standing Brief for Claude DevOps Agent
# ====================================================
# This file is automatically loaded by Claude Code at every session start.
# It provides permanent context, rules, and guardrails for autonomous
# DevOps workflows across this repository.
#
# Author: Pushparaj Naik
# Last Updated: 2026-05-24

## Project Context

**Claude DevOps** is a standalone, portable DevOps automation toolkit powered
by Claude Code. It can be dropped into any AWS / Kubernetes / Terraform project
to provide autonomous infrastructure validation, security scanning, and
CI/CD hygiene checks.

This project includes:
- Custom slash commands for Claude Code (`/pr-review`, `/security-scan`, etc.)
- Zero-dependency Python automation engines for static analysis
- Quality-gate hooks for safe, audited command execution
- Example infrastructure samples (`examples/`) for demonstration & testing

### Technology Stack
- **Cloud Provider**: AWS (us-east-1 primary, us-west-2 DR)
- **IaC**: Terraform >= 1.5 with modular architecture
- **Container Orchestration**: Amazon EKS (Kubernetes 1.28+)
- **CI/CD**: GitHub Actions with OIDC-based AWS authentication
- **GitOps**: ArgoCD
- **Secrets**: AWS Secrets Manager + External Secrets Operator
- **Monitoring**: Prometheus + Grafana stack
- **Languages**: Python 3.11+, Node.js 20+, HCL, Bash

---

## Hard Rules (NEVER VIOLATE)

### Security
1. **No hardcoded secrets** — Never embed AWS keys, database passwords, API
   tokens, or SSH private keys in source files. Use AWS Secrets Manager or
   environment variables.
2. **No `:latest` Docker tags** — All container images MUST be pinned to a
   specific digest or semver tag (e.g., `python:3.11-slim@sha256:abc123`).
3. **No wide-open security groups** — Ingress rules MUST NOT use `0.0.0.0/0`
   for ports other than 80/443. Egress should be scoped where possible.
4. **HTTPS everywhere** — All external-facing endpoints must use TLS. No
   plain HTTP listeners in production.
5. **Least-privilege IAM** — Every IAM role/policy must follow least-privilege.
   No `Action: "*"` or `Resource: "*"` in production policies.

### Terraform
1. All resources MUST have at minimum these tags: `Environment`, `Project`,
   `ManagedBy`, `Owner`.
2. Use `terraform fmt` formatting (canonical HCL style).
3. All modules MUST have `variables.tf`, `outputs.tf`, and `main.tf`.
4. Remote state MUST use S3 + DynamoDB locking.
5. Sensitive variables must use `sensitive = true`.

### Kubernetes
1. All pods MUST have resource `requests` and `limits` defined.
2. All deployments MUST have `readinessProbe` and `livenessProbe`.
3. Containers MUST NOT run as root — use `securityContext.runAsNonRoot: true`.
4. Network policies MUST be defined for every namespace.
5. Use `PodDisruptionBudget` for all production workloads.

### Git & CI/CD
1. **Branch strategy**: `main` (production), `develop` (integration),
   `feature/*`, `hotfix/*`, `release/*`.
2. All commits to `main` require PR with at least 1 approval.
3. GitHub Actions workflows MUST include `permissions` blocks.
4. Use OIDC for AWS authentication — never store long-lived credentials.

---

## Naming Conventions

| Resource Type      | Pattern                          | Example                     |
|--------------------|----------------------------------|-----------------------------|
| Terraform Module   | `kebab-case`                     | `external-secrets`          |
| AWS Resource       | `{prefix}-{env}-{resource}`      | `threetier-prod-cluster`    |
| K8s Namespace      | `kebab-case`                     | `three-tier-app`            |
| K8s Deployment     | `{app}-deployment`               | `backend-deployment`        |
| K8s Service        | `{app}-service`                  | `backend-service`           |
| Python Module      | `snake_case`                     | `sec_scanner.py`            |
| Shell Script       | `kebab-case`                     | `pre-commit.sh`             |

---

## Dangerous Commands — Require Explicit Approval

The following commands MUST NEVER be executed without explicit user
confirmation. The `hooks/pre-tool.sh` hook enforces this:

```
terraform apply
terraform destroy
kubectl delete namespace
kubectl delete deployment
kubectl delete -f
aws iam delete-*
aws s3 rb
aws ec2 terminate-instances
```

---

## File Structure Reference

```
Claude_devops/
├── CLAUDE.md                          # THIS FILE — standing brief
├── README.md                          # Project documentation
├── .claude/
│   └── commands/                      # Custom slash commands
│       ├── pr-review.md               # /pr-review [branch]
│       ├── infra-validate.md          # /infra-validate [dir]
│       ├── security-scan.md           # /security-scan [dir]
│       └── k8s-diagnostics.md         # /k8s-diagnostics [dir]
├── scripts/                           # Python automation engines
│   ├── pr_analyser.py                 # Git diff analysis & reporting
│   ├── sec_scanner.py                 # Secrets & vulnerability scanner
│   ├── tf_helper.py                   # Terraform validation helper
│   └── k8s_helper.py                  # Kubernetes manifest diagnostics
├── hooks/                             # Git & Claude hooks
│   ├── pre-tool.sh                    # Dangerous command gatekeeper
│   └── pre-commit.sh                  # Pre-commit quality gate
└── examples/                          # Sample infra for demo & testing
    ├── terraform/                     # Sample Terraform modules
    ├── k8s/                           # Sample Kubernetes manifests
    ├── docker/                        # Sample Dockerfiles
    └── .github/workflows/             # Sample CI/CD pipeline
```

---

## Response Format Guidelines

When producing reports, always use this structured format:

```markdown
## 📋 Report: [Title]
**Scan Date:** YYYY-MM-DD HH:MM
**Scope:** [directories/files scanned]

### ✅ Passed Checks
- [list of passed checks]

### ⚠️ Warnings
- [list of warnings with file:line references]

### ❌ Critical Findings
- [list of critical issues with file:line references]

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
