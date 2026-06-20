# HealthCloud — Claude Code for DevOps Automation

## Overview

This project implements all recommendations from the "Claude Code for DevOps" guide, adapting them for a HIPAA-compliant, multi-cloud healthcare platform. The automation follows the **Five Primitives** pattern:

```
┌────────────────────────────────────────────────────────────────────┐
│                    Claude Code for DevOps                          │
│                                                                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────┐  ┌─────────┐ │
│  │ Standing │  │  Slash   │  │  Quality │  │Agent│  │   MCP   │ │
│  │  Brief   │  │ Commands │  │  Hooks   │  │ CI  │  │ Servers │ │
│  │          │  │          │  │          │  │     │  │         │ │
│  │CLAUDE.md │  │6 cmds in │  │pre-tool  │  │GH   │  │AWS CLI  │ │
│  │          │  │.claude/  │  │pre-commit│  │Actions│ │kubectl  │ │
│  │          │  │commands/ │  │          │  │     │  │az CLI   │ │
│  └──────────┘  └──────────┘  └──────────┘  └─────┘  └─────────┘ │
│                                                                    │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │              6 Python Automation Engines                    │   │
│  │  sec_scanner │ k8s_helper │ tf_helper │ pr_analyser       │   │
│  │  compliance_checker │ dr_validator                         │   │
│  └────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────┘
```

---

## 1. Standing Brief (CLAUDE.md)

**Location:** `CLAUDE.md` (project root)

The standing brief provides permanent context loaded by Claude Code at every session start. It contains:

| Section | Purpose |
|---------|---------|
| Project Context | AWS primary + Azure DR, healthcare, HIPAA |
| Technology Stack | Full tech stack table |
| Hard Rules | 28 inviolable rules covering security, Terraform, K8s, CI/CD, DR |
| Naming Conventions | Patterns for every resource type |
| Dangerous Commands | 30+ commands requiring explicit approval |
| Response Format | Structured report template |

---

## 2. Custom Slash Commands

**Location:** `.claude/commands/`

| Command | File | Purpose | Engines Used |
|---------|------|---------|-------------|
| `/pr-review` | pr-review.md | Comprehensive PR analysis | sec_scanner, tf_helper, k8s_helper, compliance_checker |
| `/infra-validate` | infra-validate.md | Terraform module validation | tf_helper |
| `/security-scan` | security-scan.md | 5-engine security scan | sec_scanner, compliance_checker |
| `/k8s-diagnostics` | k8s-diagnostics.md | K8s manifest analysis | k8s_helper |
| `/dr-failover` | dr-failover.md | DR readiness validation | dr_validator |
| `/compliance-audit` | compliance-audit.md | HIPAA/GDPR compliance check | compliance_checker |

### Usage Example
```
Claude > /security-scan ./terraform
```

---

## 3. Quality Gate Hooks

**Location:** `hooks/`

### 3.1 pre-tool.sh (Dangerous Command Gatekeeper)

Intercepts 30+ dangerous commands before execution:

```
terraform destroy     → BLOCKED (requires "yes" confirmation)
kubectl delete ns     → BLOCKED
aws rds delete        → BLOCKED
az group delete       → BLOCKED
rm -rf                → BLOCKED
git push --force      → BLOCKED
```

All decisions logged to `.claude/audit.log`.

### 3.2 pre-commit.sh (6-Check Quality Gate)

| Check | What It Does | Failure Mode |
|-------|-------------|-------------|
| Secret Scanning | 7 regex patterns for AWS/Azure/GitHub credentials | ❌ BLOCK commit |
| Terraform Formatting | `terraform fmt -check` | ⚠️ WARN |
| Python Linting | `py_compile` syntax check | ❌ BLOCK commit |
| YAML Validation | `yaml.safe_load` parsing | ⚠️ WARN |
| Docker Image Pinning | Check for `:latest` tags in Dockerfiles | ❌ BLOCK commit |
| PHI Exposure | 7 patterns for potential PHI in code | ⚠️ WARN |

---

## 4. Python Automation Engines

**Location:** `scripts/devops/`

All scripts are **zero-dependency** (stdlib Python only) and output in 3 formats: text, markdown, JSON.

### 4.1 sec_scanner.py — 5-Engine Security Scanner

```
Engine 1: Secrets     (16 regex patterns) → CRITICAL findings
Engine 2: Dockerfile  (6 checks)          → HIGH/MEDIUM findings
Engine 3: Terraform   (8 checks)          → CRITICAL/HIGH findings
Engine 4: Kubernetes  (7 checks)          → HIGH findings
Engine 5: CI/CD       (4 checks)          → HIGH/MEDIUM findings
```

**Usage:**
```bash
python3 scripts/devops/sec_scanner.py --path . --format markdown
python3 scripts/devops/sec_scanner.py --path ./terraform --type terraform --format json
```

### 4.2 k8s_helper.py — K8s Manifest Diagnostics

Checks 12 aspects of every Deployment/StatefulSet:
- Security context (5 checks)
- Resources (2 checks)
- Health probes (3 checks)
- Image pinning (1 check)
- HA (2 checks)

### 4.3 tf_helper.py — Terraform Validator

Checks per module:
- Structure (main.tf, variables.tf, outputs.tf)
- Provider version pinning
- Backend configuration
- Sensitive variable marking
- Tag compliance
- Hardcoded values detection

### 4.4 pr_analyser.py — PR Risk Scoring

Categorizes changed files and calculates risk score:
- Infrastructure: weight 3 (highest risk)
- CI/CD: weight 3
- Kubernetes: weight 2
- Docker: weight 2
- Application: weight 1
- Documentation: weight 0

### 4.5 compliance_checker.py — HIPAA/GDPR Checker

Validates 12 compliance controls:
- Encryption at rest (AWS + Azure)
- Encryption in transit (TLS + mTLS)
- Audit logging (CloudTrail + Azure Monitor)
- Access controls (RBAC + NetworkPolicy)
- PHI handling
- Data residency

### 4.6 dr_validator.py — DR Readiness Validator

Checks:
- Infrastructure parity (8 categories: compute, database, storage, cache, networking, security, monitoring, DNS)
- Failover configuration (health checks, DNS failover, Traffic Manager, VPN)
- Database replication
- RTO/RPO estimates

---

## 5. Defence-in-Depth Security Model

```
Layer 1: PREVENTION (CLAUDE.md rules)
    │
    ├── Hard rules prevent insecure code from being written
    ├── Naming conventions enforce consistency
    └── Dangerous commands list prevents accidents
    │
Layer 2: DETECTION (Python scanners)
    │
    ├── 5-engine scanner catches security issues
    ├── Compliance checker validates HIPAA controls
    └── DR validator ensures failover readiness
    │
Layer 3: ENFORCEMENT (Hooks + CI/CD gates)
    │
    ├── pre-tool.sh blocks dangerous commands
    ├── pre-commit.sh blocks commits with secrets
    ├── Trivy blocks images with CRITICAL CVEs
    └── tfsec/Checkov block insecure Terraform
```

---

## 6. Audit Trail

All agent decisions are logged:

**File:** `.claude/audit.log`

```
[2026-06-18 08:30:00] BLOCKED: terraform destroy (pattern: terraform destroy)
[2026-06-18 08:35:00] APPROVED: terraform apply (pattern: terraform apply)
[2026-06-18 09:00:00] BLOCKED: kubectl delete namespace (pattern: kubectl delete namespace)
```

---

## 7. Integration Points

| Tool | Integration | Purpose |
|------|------------|---------|
| AWS CLI | MCP server / direct CLI | Infrastructure management |
| kubectl | MCP server / direct CLI | K8s cluster management |
| terraform | Direct CLI | Infrastructure provisioning |
| az CLI | Direct CLI | Azure resource management |
| git | Direct CLI | Version control |
| argocd | Direct CLI | GitOps deployment |
| GitHub Actions | CI/CD pipelines | Automated workflows |

---

## 8. Getting Started

```bash
# 1. Clone the repository
git clone https://github.com/healthcloud/healthcloud-multiregion-dr.git
cd healthcloud-multiregion-dr

# 2. Install pre-commit hook
cp hooks/pre-commit.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# 3. Run security scan
python3 scripts/devops/sec_scanner.py --path . --format markdown

# 4. Run compliance check
python3 scripts/devops/compliance_checker.py --path . --format markdown

# 5. Set up state backends
./scripts/ops/setup-backends.sh dev

# 6. Initialize Terraform
cd terraform/environments/dev
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
```
