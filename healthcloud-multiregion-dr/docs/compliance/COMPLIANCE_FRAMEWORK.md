# HealthCloud — Compliance Framework

## 1. HIPAA Technical Safeguards Control Mapping

| HIPAA Section | Control | Implementation | Status |
|---------------|---------|----------------|--------|
| **§ 164.312(a)(1)** | Access Control | K8s RBAC, IAM least-privilege, IRSA, Workload Identity | ✅ |
| **§ 164.312(a)(2)(i)** | Unique User ID | IAM users, SSO (no shared accounts) | ✅ |
| **§ 164.312(a)(2)(ii)** | Emergency Access | DR failover script, break-glass IAM role | ✅ |
| **§ 164.312(a)(2)(iii)** | Automatic Logoff | Session TTL (DynamoDB), token expiry | ✅ |
| **§ 164.312(a)(2)(iv)** | Encryption at Rest | KMS CMK (AWS), Key Vault CMK (Azure) | ✅ |
| **§ 164.312(b)** | Audit Controls | CloudTrail, Azure Activity Log, VPC Flow Logs | ✅ |
| **§ 164.312(c)(1)** | Integrity Controls | S3 Object Lock (WORM), Blob immutability | ✅ |
| **§ 164.312(c)(2)** | Integrity Validation | CloudTrail log validation, checksums | ✅ |
| **§ 164.312(d)** | Person Authentication | MFA, OIDC, certificate-based auth | ✅ |
| **§ 164.312(e)(1)** | Transmission Security | TLS 1.3, Istio mTLS STRICT | ✅ |
| **§ 164.312(e)(2)(i)** | Integrity Controls (transit) | mTLS, message signing | ✅ |
| **§ 164.312(e)(2)(ii)** | Encryption (transit) | TLS 1.3 everywhere, no plain HTTP | ✅ |
| **§ 164.502** | PHI Use & Disclosure | PHI tokenization, no PHI in logs, data masking | ✅ |
| **§ 164.530** | Administrative Requirements | BAA with AWS/Azure, incident response plan | ✅ |

---

## 2. GDPR Data Protection Controls

| Article | Requirement | Implementation |
|---------|-------------|----------------|
| **Art. 5** | Data Processing Principles | Purpose limitation, data minimization |
| **Art. 17** | Right to Erasure | Soft-delete architecture, cascade delete APIs |
| **Art. 25** | Data Protection by Design | Privacy-by-default, encryption, access controls |
| **Art. 32** | Security of Processing | Full encryption, access logging, incident response |
| **Art. 33** | Breach Notification | GuardDuty alerts, 72-hour notification process |
| **Art. 35** | Data Protection Impact Assessment | DPIA documented for PHI processing |
| **Art. 44** | Data Transfers | SCP restricts data to approved regions, DPA with providers |

---

## 3. SOC 2 Trust Service Criteria

| TSC | Criteria | Implementation |
|-----|----------|----------------|
| **CC1** | Control Environment | IaC-managed, PR reviews, approval gates |
| **CC2** | Communication | Architecture docs, runbooks, incident playbooks |
| **CC3** | Risk Assessment | Threat modeling, security scanning, DR testing |
| **CC5** | Control Activities | Automated security gates, compliance checks |
| **CC6** | Logical Access | RBAC, IRSA, Workload Identity, no shared creds |
| **CC7** | System Operations | Monitoring, alerting, automated remediation |
| **CC8** | Change Management | Git-based, PR reviews, manual approval for prod |
| **CC9** | Risk Mitigation | DR strategy, backup/restore, secret rotation |
| **A1** | Availability | Multi-AZ, multi-cloud DR, 99.99% target |
| **C1** | Confidentiality | Encryption at rest and transit, data classification |
| **PI1** | Processing Integrity | Input validation, audit trails, reconciliation |
| **P1** | Privacy | Consent management, PHI masking, right to erasure |

---

## 4. Data Classification

| Level | Label | Examples | Encryption | Access | Retention |
|-------|-------|---------|------------|--------|-----------|
| **Level 4** | PHI | Patient records, diagnoses, prescriptions | KMS CMK + TLS 1.3 | Named individuals only | 7 years (HIPAA) |
| **Level 3** | Confidential | API keys, database passwords, internal configs | KMS/KV encrypted | Service accounts only | Per policy |
| **Level 2** | Internal | Monitoring data, logs (no PHI), metrics | At-rest encryption | Team members | 1 year |
| **Level 1** | Public | Static assets, marketing content | Optional | Anyone | N/A |

---

## 5. Audit Trail Requirements

| Event | AWS Source | Azure Source | Retention |
|-------|-----------|-------------|-----------|
| API calls | CloudTrail | Activity Log | 7 years (S3 WORM) |
| Network traffic | VPC Flow Logs | NSG Flow Logs | 1 year |
| Database access | Aurora audit logs | PG audit extension | 7 years |
| K8s API calls | EKS audit logs | AKS audit logs | 1 year |
| Container events | CloudWatch Logs | Log Analytics | 1 year |
| Secret access | CloudTrail | Key Vault audit | 7 years |
| IAM changes | CloudTrail | Azure AD audit | 7 years |

---

## 6. Compliance Automation

### 6.1 Automated Checks

| Check | Tool | Frequency | Pipeline |
|-------|------|-----------|----------|
| Secret detection | sec_scanner.py (Engine 1) | Every commit | pre-commit.sh |
| Terraform security | sec_scanner.py (Engine 3) + tfsec + Checkov | Every PR | infra-ci-cd.yml |
| K8s security | sec_scanner.py (Engine 4) + k8s_helper.py | Every PR | infra-ci-cd.yml |
| Container CVEs | Trivy | Every build | app-build-deploy.yml |
| HIPAA compliance | compliance_checker.py | Nightly | security-scan.yml |
| DR readiness | dr_validator.py | Monthly | dr-failover-test.yml |

### 6.2 Compliance Dashboard

```bash
# Generate full compliance report
python3 scripts/devops/compliance_checker.py --path . --format markdown

# Generate security posture report
python3 scripts/devops/sec_scanner.py --path . --format markdown

# Generate DR readiness report
python3 scripts/devops/dr_validator.py --path ./terraform --format markdown
```

---

## 7. Business Associate Agreements (BAA)

| Provider | Service | BAA Status | Reference |
|----------|---------|------------|-----------|
| AWS | All HIPAA-eligible services | ✅ Active | AWS BAA via Organizations |
| Microsoft Azure | All HIPAA-eligible services | ✅ Active | Azure HIPAA BAA |
| GitHub | GitHub Enterprise | ✅ Active | GitHub DPPA |
| Datadog/PagerDuty | Monitoring (no PHI) | N/A | No PHI processed |
