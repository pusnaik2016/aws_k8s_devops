# HIPAA / SOC 2 / PCI-DSS Compliance Control Matrix

## Enterprise Multi-Cloud Medallion Data Platform

This document maps each regulatory control requirement to the specific infrastructure resource, pipeline component, or process that satisfies it.

---

## HIPAA — Health Insurance Portability and Accountability Act

### Technical Safeguards (45 CFR §164.312)

| Control ID | Requirement | Implementation | Resource / File |
|-----------|-------------|----------------|-----------------|
| §164.312(a)(1) | Access Control — Unique user identification | Unity Catalog RBAC + SCIM provisioning from Entra ID | `aws-databricks/main.tf`, `azure-databricks/main.tf` |
| §164.312(a)(2)(i) | Unique User Identification | SCIM sync from central IdP, no shared accounts | Databricks workspace SCIM config |
| §164.312(a)(2)(iv) | Encryption and Decryption | CMK encryption at rest (KMS/Key Vault), TLS 1.3 in transit | `aws-security/main.tf` (KMS), `azure-security/main.tf` (Key Vault) |
| §164.312(b) | Audit Controls | CloudTrail (365d), VPC Flow Logs, Unity Catalog audit logs, Key Vault diagnostics | `aws-security/main.tf` (CloudTrail), `aws-networking/main.tf` (Flow Logs) |
| §164.312(c)(1) | Integrity — ePHI protection | PII tokenization in Silver layer, Object Lock on audit bucket | `silver_transformation.py`, `aws-storage/main.tf` (Object Lock) |
| §164.312(d) | Person/Entity Authentication | OIDC federation, IAM roles, Managed Identity — no static credentials | `aws-security/main.tf` (OIDC), `azure-security/main.tf` (MI) |
| §164.312(e)(1) | Transmission Security | TLS 1.3 minimum, IPSec IKEv2 (AES-256-GCM) for cross-cloud | `cross-cloud-transit/main.tf`, VPC Endpoint HTTPS |
| §164.312(e)(2)(ii) | Encryption (in transit) | VPC Endpoints (HTTPS), Direct Connect + ExpressRoute, IPSec VPN | `aws-networking/main.tf` (VPCe), `cross-cloud-transit/main.tf` |

### Administrative Safeguards

| Control ID | Requirement | Implementation |
|-----------|-------------|----------------|
| §164.308(a)(1) | Risk Analysis | AWS Config conformance packs, Azure Policy assignments |
| §164.308(a)(4) | Information Access Management | Unity Catalog grants, RLS, column masking |
| §164.308(a)(5) | Security Awareness | Automated compliance dashboard (CloudWatch/Log Analytics) |
| §164.308(a)(6) | Security Incident Procedures | SNS alerts on unauthorized access, CloudWatch alarms |

---

## SOC 2 — Trust Service Criteria

### Common Criteria (CC)

| Control | Criteria | Implementation | Resource |
|---------|----------|----------------|----------|
| CC1.1 | COSO Principle 1 — Integrity & Ethics | Automated policy enforcement (AWS Config, Azure Policy) | `aws-monitoring/main.tf`, `azure-security/main.tf` |
| CC5.1 | Logical Access — Authentication | OIDC federation, no static secrets in CI/CD | `aws-security/main.tf` (OIDC provider), `cd-deploy.yml` |
| CC5.2 | Logical Access — Provisioning | SCIM from Entra ID, automated offboarding | Databricks SCIM configuration |
| CC6.1 | Logical Access — Credential Management | 90-day automated rotation, secret scope redaction | `secrets-rotation/main.tf`, `rotate_secrets.py` |
| CC6.2 | Logical Access — Restriction | VPC Endpoint restriction, NSG deny-all, Private Link | `aws-networking/main.tf`, `azure-networking/main.tf` |
| CC6.3 | Logical Access — Authorization | Unity Catalog RBAC, IAM least-privilege policies | `aws-databricks/main.tf` (cluster policy) |
| CC6.6 | Logical Access — Boundary Protection | VPC/VNet isolation, NACLs, Security Groups, no public IPs | `aws-networking/main.tf` (NACLs), `azure-networking/main.tf` (NSGs) |
| CC7.1 | System Operations — Monitoring | CloudWatch dashboards, Log Analytics alerts, unauthorized API detection | `aws-monitoring/main.tf`, `azure-monitoring/main.tf` |
| CC7.2 | System Operations — Incident Detection | Metric alarms (root usage, S3 policy changes, KMS deletion) | `aws-monitoring/main.tf` (alarms) |
| CC8.1 | Change Management — Authorized Changes | DAB bundle deploy via CI/CD only, configuration drift check | `cd-deploy.yml` (drift_check job) |
| CC9.1 | Risk Mitigation — DR Capability | Active-Passive Pilot Light (AWS → Azure), VPN failover | `cross-cloud-transit/main.tf`, `dr-standby/main.tf` |

---

## PCI-DSS v4.0 — Payment Card Industry Data Security Standard

### Network Security

| Req | Requirement | Implementation | Resource |
|-----|-------------|----------------|----------|
| 1.2 | Network segmentation | 3-tier VPC subnets (Public/Compute/Data), NACLs, NSGs | `aws-networking/main.tf`, `azure-networking/main.tf` |
| 1.3 | Restrict inbound/outbound traffic | VPC Endpoint restriction, deny-all NSG rules | Bucket policies, NSG security rules |
| 1.4 | Firewall between CDE and untrusted | NACLs restricting data-tier to compute-tier only | `aws-networking/main.tf` (NACL) |

### Protect Cardholder Data

| Req | Requirement | Implementation | Resource |
|-----|-------------|----------------|----------|
| 3.4 | Render PAN unreadable | Format-preserving tokenization (last 4 visible) | `silver_transformation.py`, `encryption.py` |
| 3.5 | Protect cryptographic keys | KMS/Key Vault with access policies, CMK blast-radius isolation | `aws-security/main.tf` (3 CMKs), `azure-security/main.tf` |
| 3.6 | Key management procedures | 90-day automated rotation, key deletion window | `secrets-rotation/main.tf` |
| 4.1 | Encrypt transmission | TLS 1.3 minimum, IPSec AES-256-GCM | VPC Endpoints, `cross-cloud-transit/main.tf` |

### Vulnerability Management

| Req | Requirement | Implementation | Resource |
|-----|-------------|----------------|----------|
| 6.2 | Security patches | Databricks runtime auto-updates, managed services | Databricks workspace config |
| 6.5 | Secure development | SAST scan (Trivy), 0 critical vulnerability gate | `ci-validate.yml` (sast_scan job) |
| 6.6 | Code review | GitHub PR-based review, automated validation | `ci-validate.yml` |

### Access Control

| Req | Requirement | Implementation | Resource |
|-----|-------------|----------------|----------|
| 7.1 | Restrict access by business need | Unity Catalog grants, IAM least-privilege | Databricks catalog permissions |
| 7.2 | Access control systems | RBAC (Unity Catalog), ABAC (row-level security) | `aws-databricks/main.tf` |
| 8.2 | Unique identification | SCIM provisioning, no shared service accounts | Entra ID SCIM config |
| 8.2.4 | Password rotation | 90-day automated rotation | `secrets-rotation/main.tf` |
| 8.3 | Multi-factor authentication | MFA enforced via Entra ID conditional access | IdP configuration |

### Monitoring

| Req | Requirement | Implementation | Resource |
|-----|-------------|----------------|----------|
| 10.1 | Audit trail | CloudTrail (data events), Unity Catalog audit logs | `aws-security/main.tf` (CloudTrail) |
| 10.2 | Audit log contents | User ID, event type, timestamp, success/failure | CloudTrail data event format |
| 10.3 | Audit log protection | Immutable S3 bucket (Object Lock, 365d governance) | `aws-storage/main.tf` (audit_logs bucket) |
| 10.5 | Secure audit trails | CMK encryption on log storage, deny-delete policy | `aws-storage/main.tf` (bucket policy) |
| 10.7 | Log retention | 365-day retention on all audit logs | CloudWatch (365d), Log Analytics (365d) |

---

## Audit KPI Mapping (Section IV Compliance)

| Metric Category | Parameter | Target | Implementation |
|-----------------|-----------|--------|----------------|
| Identity/Audit | Access Log Trail | 100% immutable capture | CloudTrail data events + Object Lock audit bucket |
| Data Integrity | Encryption Validation | 100% CMK enforced | AWS Config rule `s3-bucket-server-side-encryption-enabled` + S3 deny policy |
| Vulnerability | SAST Code Scanning | 0 Critical | Trivy scan in `ci-validate.yml` with exit-code 1 gate |
| Pipeline State | Deployment Drift | 0 Config Gaps | `cd-deploy.yml` drift_check job comparing bundle validation |
