# 🏥 HealthCloud Multi-Region DR Platform

> HIPAA-compliant healthcare platform with AWS (primary) + Azure (DR), fully automated with Claude Code for DevOps

[![Infrastructure CI/CD](https://github.com/healthcloud/healthcloud-multiregion-dr/actions/workflows/infra-ci-cd.yml/badge.svg)](https://github.com/healthcloud/healthcloud-multiregion-dr/actions)
[![Security Scan](https://github.com/healthcloud/healthcloud-multiregion-dr/actions/workflows/security-scan.yml/badge.svg)](https://github.com/healthcloud/healthcloud-multiregion-dr/actions)
[![DR Failover Test](https://github.com/healthcloud/healthcloud-multiregion-dr/actions/workflows/dr-failover-test.yml/badge.svg)](https://github.com/healthcloud/healthcloud-multiregion-dr/actions)

## Architecture Overview

```
                         Route 53 (Failover)
                         ┌───────┐
                         │  DNS  │
                         └───┬───┘
                    ┌────────┴────────┐
              ┌─────▼─────┐    ┌─────▼─────┐
              │ AWS        │    │ Azure      │
              │ us-east-1  │    │ eastus     │
              │ (PRIMARY)  │    │ (DR)       │
              │            │    │            │
              │ CloudFront │    │ Front Door │
              │ WAF v2     │    │ WAF        │
              │ EKS 1.30   │    │ AKS 1.30   │
              │ Aurora PG  │◄──►│ PG Flex    │
              │ Redis 7    │    │ Redis      │
              │ S3 (PHI)   │    │ Blob (PHI) │
              └────────────┘    └────────────┘
                    │     VPN (IPSec)   │
                    └───────────────────┘
```

| Metric | Target | Design |
|--------|--------|--------|
| **RPO** | < 15 min | ~10 min (async replication) |
| **RTO** | < 30 min | ~21 min (automated) |
| **Availability** | 99.99% | Multi-AZ + Multi-Cloud |
| **Compliance** | HIPAA, GDPR, SOC 2 | Full coverage |

## 🧠 Claude Code for DevOps — Features

| Feature | Implementation |
|---------|----------------|
| Standing Brief | `CLAUDE.md` — 200+ lines of permanent agent context |
| 6 Slash Commands | `/pr-review`, `/infra-validate`, `/security-scan`, `/k8s-diagnostics`, `/dr-failover`, `/compliance-audit` |
| Quality Gate Hooks | `pre-tool.sh` (30+ dangerous commands blocked), `pre-commit.sh` (6-check gate) |
| 6 Python Engines | `sec_scanner`, `k8s_helper`, `tf_helper`, `pr_analyser`, `compliance_checker`, `dr_validator` |
| 4 CI/CD Pipelines | Infra, App Build, Security Scan, DR Failover Test |
| Defence-in-Depth | Prevention → Detection → Enforcement |

## 📂 Project Structure

```
healthcloud-multiregion-dr/
├── CLAUDE.md                          # 🧠 Standing Brief
├── .claude/commands/                  # 🎮 6 Slash Commands
├── hooks/                             # 🛡️ Quality Gate Hooks
├── scripts/devops/                    # 🐍 6 Python Automation Engines
├── scripts/ops/                       # 🔧 4 Operations Scripts
├── apps/                              # 🐳 4 Application Dockerfiles
├── terraform/
│   ├── aws/                           # ☁️ AWS Primary (6 modules)
│   ├── azure/                         # 🔷 Azure DR (6 modules)
│   ├── environments/                  # 🌍 dev/staging/prod
│   ├── variables.tf
│   └── versions.tf
├── kubernetes/
│   ├── base/                          # ☸️ Namespaces, NetworkPolicies, RBAC
│   ├── apps/                          # 📱 4 Service Deployments
│   ├── istio/                         # 🕸️ Service Mesh (mTLS, AuthZ)
│   └── argocd/                        # 🔄 GitOps Applications
├── .github/workflows/                 # ⚙️ 4 CI/CD Pipelines
└── docs/                              # 📚 Architecture, Runbook, Compliance
```

## 🚀 Quick Start

```bash
# 1. Install pre-commit hook
cp hooks/pre-commit.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit

# 2. Run security scan
python3 scripts/devops/sec_scanner.py --path . --format markdown

# 3. Set up state backends
./scripts/ops/setup-backends.sh dev

# 4. Initialize & plan
cd terraform/environments/dev
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
```

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/architecture/ARCHITECTURE.md) | System context, network topology, data flow, DR strategy |
| [Design Details](docs/architecture/DESIGN_DETAILS.md) | Microservice design, database decisions, security model, cost |
| [Operations Runbook](docs/runbooks/OPERATIONS_RUNBOOK.md) | Day-to-day ops, DR procedures, incident response, troubleshooting |
| [Compliance Framework](docs/compliance/COMPLIANCE_FRAMEWORK.md) | HIPAA/GDPR/SOC 2 control mapping |
| [DevOps Automation](docs/claude-code/DEVOPS_AUTOMATION.md) | Claude Code integration, Python engines, hooks |

## 🏥 Healthcare Services

| Service | Language | Purpose | Port |
|---------|----------|---------|------|
| patient-service | Java 21 | Patient CRUD, FHIR, search | 8080 |
| imaging-service | Java 21 | DICOM storage, medical imaging | 8080 |
| pharmacy-service | Java 21 | Prescriptions, drug database | 8080 |
| notification-service | Python 3.12 | Email, SMS, push notifications | 8080 |

## License

Proprietary — HealthCloud Platform Team
