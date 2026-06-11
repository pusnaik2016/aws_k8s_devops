# MedCloud Global — Compliance & Regulatory Framework

## 1. Compliance Matrix

### 1.1 Regulation-to-Control Mapping

| Control Area | HIPAA Requirement | GDPR Requirement | PCI-DSS Requirement | MedCloud Implementation |
|---|---|---|---|---|
| **Data Encryption (at rest)** | § 164.312(a)(2)(iv) — Encryption | Art. 32(1)(a) — Pseudonymisation | Req 3.4 — Render PAN unreadable | AES-256 CMK encryption on all storage (AWS KMS, Azure Key Vault, GCP Cloud KMS) |
| **Data Encryption (in transit)** | § 164.312(e)(1) — Transmission security | Art. 32(1)(a) — Encryption | Req 4.1 — Encrypt cardholder data | TLS 1.3 everywhere, Istio mTLS (STRICT mode) |
| **Access Control** | § 164.312(a)(1) — Unique user ID | Art. 25 — Data protection by design | Req 7 — Restrict access to need-to-know | Cloud IAM + K8s RBAC + Istio AuthorizationPolicy |
| **Audit Logging** | § 164.312(b) — Audit controls | Art. 30 — Records of processing | Req 10 — Track all access | VPC Flow Logs, CloudTrail, Azure Audit, Cloud Audit Logs |
| **Breach Notification** | § 164.404 — 60-day notification | Art. 33 — 72-hour notification | Req 12.10 — Incident response plan | PagerDuty + HIPAA breach protocol in runbook |
| **Data Minimization** | § 164.502(b) — Minimum necessary | Art. 5(1)(c) — Data minimization | Req 3.1 — Limit data retention | DynamoDB TTL, Cosmos DB per-doc TTL, BigQuery partition expiry |
| **Right to Erasure** | N/A | Art. 17 — Right to erasure | N/A | `gdpr_deletion_requested_at` field, automated purge pipeline |
| **Network Segmentation** | § 164.312(e)(1) — Technical safeguards | Art. 32 — Security of processing | Req 1 — Firewall configuration | 3-tier subnets, NSGs, K8s NetworkPolicy, deny-all defaults |
| **Vulnerability Management** | § 164.308(a)(5) — Security awareness | Art. 32 — Regular testing | Req 6.1 — Patch vulnerabilities | tfsec, Checkov, Trivy, GuardDuty, Defender, SCC |
| **Key Management** | § 164.312(a)(2)(iv) | Art. 32 | Req 3.5-3.6 — Key management | CMK with 90-day rotation, HSM-backed (Azure Key Vault Premium) |
| **Data Residency** | N/A (US-focused) | Art. 44-49 — Cross-border transfers | N/A | Azure EU region for EU patients, PHI stays in originating cloud |

---

## 2. Cloud-Specific Compliance Posture

### 2.1 AWS

| Service | Compliance Feature | Status |
|---------|-------------------|--------|
| AWS Security Hub | CIS Benchmarks + PCI-DSS standards enabled | ✅ Active |
| AWS GuardDuty | K8s audit, S3, malware protection | ✅ Active |
| AWS Config | Configuration recording + compliance rules | ✅ Active |
| CloudTrail | Multi-region, encrypted, org-level | ✅ Active |
| KMS | CMK with auto-rotation (90-day) | ✅ Active |
| WAF v2 | OWASP + SQLi + rate limiting + geo-blocking | ✅ Active |
| VPC Flow Logs | Encrypted with KMS, CloudWatch | ✅ Active |

### 2.2 Azure

| Service | Compliance Feature | Status |
|---------|-------------------|--------|
| Defender for Cloud | HIPAA + PCI-DSS regulatory compliance | ✅ Active |
| Defender for Containers | Image scanning, runtime protection | ✅ Active |
| Azure Sentinel | Cross-cloud SIEM, threat correlation | ✅ Active |
| Key Vault | HSM-backed (Premium), purge protection | ✅ Active |
| Azure Firewall | Premium with IDPS + TLS inspection (prod) | ✅ Active |
| Azure Bastion | Zero-trust VM access (no public SSH/RDP) | ✅ Active |
| Log Analytics | Encrypted, 365-day retention (prod) | ✅ Active |

### 2.3 GCP

| Service | Compliance Feature | Status |
|---------|-------------------|--------|
| Security Command Center | Vulnerability + threat detection | ✅ Active |
| Binary Authorization | Only signed container images deploy | ✅ Active (prod) |
| Cloud DLP | PHI/PII detection + de-identification | ✅ Active |
| Cloud KMS | CMK with 90-day rotation | ✅ Active |
| VPC Service Controls | Restrict data exfiltration | ✅ Active (prod) |
| IAP | Zero-trust SSH access (no public SSH) | ✅ Active |
| GKE Sandbox (gVisor) | Kernel-level isolation for ML workloads | ✅ Active |

---

## 3. Data Classification

| Classification | Description | Examples | Storage Location | Encryption | Access |
|---|---|---|---|---|---|
| 🔴 **PHI** | Protected Health Information | Patient records, diagnoses, prescriptions, DICOM images | Azure (Cosmos DB, Blob Storage) | CMK + column-level | Patient Service SA only |
| 🟡 **PCI** | Payment Card Industry data | Card numbers (tokenized), transaction records | AWS (Aurora, DynamoDB) | CMK + tokenization | Order Service SA only |
| 🟠 **PII** | Personally Identifiable Information | Names, emails, phone numbers, addresses | AWS + Azure (encrypted columns) | CMK + column-level | Respective service SA |
| 🟢 **De-identified** | Anonymized analytics data | Tokenized IDs, aggregated metrics | GCP (BigQuery, Cloud Storage) | CMK | Analytics team |
| ⚪ **Public** | Non-sensitive data | Product catalog, static assets, documentation | AWS (S3, CloudFront) | Default encryption | Public CDN |

---

## 4. Compliance Automation

### 4.1 Pre-Deployment Checks (CI/CD Pipelines)

Three GitHub Actions workflows enforce compliance at every stage:

**Infrastructure Pipeline** (`.github/workflows/medcloud-infra.yml`):

| Tool | Check | Fail Criteria |
|------|-------|---------------|
| tfsec | Terraform security rules | Any HIGH/CRITICAL finding |
| Checkov | CIS, HIPAA, PCI-DSS benchmarks | Policy violation |
| SARIF Upload | GitHub Code Scanning integration | Findings tracked |

**Application Pipeline** (`.github/workflows/medcloud-app-build.yml`):

| Tool | Check | Fail Criteria |
|------|-------|---------------|
| SonarQube | SAST — code quality + vulnerabilities | Quality gate fails |
| OWASP Dependency Check | SCA — known CVEs in dependencies | CVSS ≥ 7 |
| JaCoCo | Code coverage enforcement | < 70% line coverage |
| Trivy | Container image CVEs | CRITICAL or HIGH severity |

**Nightly Security Scan** (`.github/workflows/medcloud-security-scan.yml`):

| Check | Schedule | Scope |
|-------|----------|-------|
| Container drift scan | Daily 02:00 UTC | All 6 images across ECR/ACR/GAR |
| Checkov + tfsec audit | Daily 02:00 UTC | All Terraform configs |
| ZAP DAST | Daily 02:00 UTC | API endpoints |

### 4.2 Container Image Compliance

All Dockerfiles enforce HIPAA-hardened security:

| Control | Implementation | Compliance |
|---------|---------------|------------|
| Non-root execution | `USER medcloud:medcloud` | HIPAA § 164.312(a) |
| Minimal attack surface | Multi-stage build, Alpine/slim base | PCI-DSS Req 2.2 |
| Image immutability | ECR immutable tags (`v*`), ACR content trust | PCI-DSS Req 6 |
| Health monitoring | `HEALTHCHECK` directive + K8s probes | HIPAA § 164.312(b) |
| Compliance labeling | OCI labels (`compliance.hipaa=true`) | Audit trail |
| Scan on push | ECR scan-on-push, Defender for Containers | Req 6.1 |

### 4.3 Runtime Compliance Monitoring

```
CONTINUOUS COMPLIANCE:

┌────────────────────────┐
│  AWS Security Hub      │──── CIS Benchmarks
│  + AWS Config          │──── PCI-DSS v3.2.1
│                        │──── AWS Best Practices
├────────────────────────┤
│  Azure Defender        │──── HIPAA/HITRUST
│  + Azure Policy        │──── PCI-DSS
│  + Sentinel            │──── GDPR
├────────────────────────┤
│  GCP SCC               │──── CIS Benchmarks
│  + Org Policies         │──── HIPAA
│  + VPC Service Controls │──── Data Residency
└────────────────────────┘
         │
         ▼
┌────────────────────────┐
│  Unified Dashboard     │
│  (Grafana + Prisma     │
│   Cloud)               │
│                        │
│  KPIs:                 │
│  • Compliance Score    │
│  • Open Findings       │
│  • Mean Time to        │
│    Remediate (MTTR)    │
│  • Drift Detection     │
└────────────────────────┘
```

### 4.4 Secret Rotation Compliance

Secret rotation is enforced via `scripts/rotate-secrets.sh`:

| Cloud | Secret Store | Rotation Period | Mechanism |
|-------|-------------|-----------------|-----------|
| AWS | Secrets Manager | 90 days | Lambda-based auto-rotation |
| Azure | Key Vault | 90 days | Expiry policy + alert |
| GCP | Secret Manager | 90 days | Version-based rotation |

---

## 5. Audit Trail Requirements

| Event Type | Retention (HIPAA) | Retention (PCI) | Retention (GDPR) | Storage |
|------------|------------------|-----------------|------------------|---------|
| API access logs | 6 years | 1 year | As needed | CloudWatch / Log Analytics / Cloud Logging |
| Database queries | 6 years | 1 year | As needed | Performance Insights / Cosmos DB diagnostics |
| Authentication events | 6 years | 1 year | As needed | CloudTrail / Entra ID / Cloud Audit |
| Infrastructure changes | 6 years | 1 year | As needed | Terraform state history / CloudTrail |
| Data access (PHI) | 6 years | N/A | As needed | Istio access logs + service audit logs |
| Security findings | 6 years | 1 year | As needed | Security Hub / Defender / SCC |
| CI/CD pipeline runs | 6 years | 1 year | As needed | GitHub Actions audit log |
| Container image scans | 6 years | 1 year | As needed | SARIF in GitHub Code Scanning |
| Secret rotation events | 6 years | 1 year | As needed | CloudTrail / Key Vault Audit / Cloud Audit |

---

**Document Version:** 2.0 | **Last Updated:** 2026-06-11 | **Author:** Pushparaj Naik | **Classification:** Internal — Confidential


### 4.1 Pre-Deployment Checks (CI/CD)

