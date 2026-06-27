# Compliance Controls — PCI-DSS, SOC2, HIPAA, GDPR

## PCI-DSS v3.2.1 Controls

### Requirement 1: Install and Maintain a Firewall Configuration
| Sub-Req | Control | Implementation | Evidence |
|---|---|---|---|
| 1.2 | Restrict connections | VPC Security Groups, default-deny NetworkPolicies | `terraform/modules/vpc/main.tf`, `kubernetes/base/network-policies/` |
| 1.3 | Prohibit direct public access | Private subnets for EKS, VPC Endpoints | `terraform/modules/vpc/main.tf` (no IGW route to private) |
| 1.3.4 | DMZ architecture | 3-tier subnet (public/private/database) | VPC module subnet design |

### Requirement 2: Do Not Use Vendor-Supplied Defaults
| Sub-Req | Control | Implementation |
|---|---|---|
| 2.1 | Change defaults | Custom security groups, non-default ports |
| 2.2.1 | One function per server | Microservice architecture, one pod per service |

### Requirement 3: Protect Stored Cardholder Data
| Sub-Req | Control | Implementation |
|---|---|---|
| 3.4 | Render PAN unreadable | KMS envelope encryption (EKS secrets, Aurora, EBS) |
| 3.5 | Protect encryption keys | KMS auto-rotation, IAM policies |
| 3.6 | Key management procedures | KMS key policies, 30-day deletion window |

### Requirement 4: Encrypt Transmission of Cardholder Data
| Sub-Req | Control | Implementation |
|---|---|---|
| 4.1 | Strong cryptography | Istio STRICT mTLS, TLS 1.2+ gateway, Aurora SSL |

### Requirement 6: Develop and Maintain Secure Systems
| Sub-Req | Control | Implementation |
|---|---|---|
| 6.3 | Secure development | SonarCloud SAST, code review via PR |
| 6.5 | Address common vulnerabilities | OWASP SCA, Safety, pip-audit |
| 6.6 | Web application firewall | WAF v2 (SQLi, XSS, rate limiting, bad inputs), Trivy container scanning |

### Requirement 7: Restrict Access by Business Need-to-Know
| Sub-Req | Control | Implementation |
|---|---|---|
| 7.1 | Limit access | K8s RBAC (viewer/admin roles), IRSA (per-service IAM) |
| 7.2 | Privilege management | ServiceAccounts per pod, no shared credentials |

### Requirement 8: Identify and Authenticate All Users
| Sub-Req | Control | Implementation |
|---|---|---|
| 8.2 | Unique IDs | IAM authentication for Aurora, IRSA for AWS |
| 8.5 | No shared accounts | Individual AWS IAM, K8s ServiceAccounts |

### Requirement 10: Track and Monitor All Access
| Sub-Req | Control | Implementation |
|---|---|---|
| 10.1 | Audit trails | CloudTrail (multi-region, log validation) |
| 10.2 | Automated audit trails | EKS audit logs (all 5 types enabled) |
| 10.5 | Secure audit trails | S3 versioning, KMS encryption, bucket policy |
| 10.7 | 1-year retention | CloudWatch 365-day, S3 Glacier archive |

### Requirement 11: Regularly Test Security Systems
| Sub-Req | Control | Implementation |
|---|---|---|
| 11.4 | IDS/IPS | GuardDuty (EKS audit + S3 monitoring) |
| 11.5 | Change detection | Security Hub (CIS, AWS Foundational benchmarks) |

---

## SOC2 Trust Service Criteria

| Criteria | Control | Implementation |
|---|---|---|
| CC6.1 | Logical + physical access | IAM, RBAC, VPC isolation, KMS |
| CC6.3 | Role-based access | RBAC ClusterRoles (viewer/admin), IRSA |
| CC6.8 | Threat detection | GuardDuty, Security Hub |
| CC7.2 | System monitoring | CloudTrail + EKS audit logs + CloudWatch |
| CC7.3 | Security events | GuardDuty findings, Security Hub alerts |

---

## HIPAA Security Rule

| Section | Control | Implementation |
|---|---|---|
| §164.312(a)(2)(iv) | Encryption at rest | KMS encryption for all data stores |
| §164.312(e)(1) | Encryption in transit | Istio mTLS, TLS 1.2+, Aurora SSL |
| §164.312(b) | Audit controls | CloudTrail, EKS audit, 365-day retention |
| §164.312(d) | Person authentication | IAM, IRSA, no static credentials |
| §164.308(a)(5)(ii)(C) | Log-in monitoring | CloudTrail API logging, GuardDuty |

---

## GDPR

| Article | Control | Implementation |
|---|---|---|
| Art. 25 | Data protection by design | PII masking in FluentBit (Lua script) |
| Art. 32 | Security of processing | Encryption at rest + in transit |
| Art. 33 | Breach notification | GuardDuty → SNS → PagerDuty (72h SLA) |
| Art. 35 | Data protection impact | Separate payment namespace, minimal data retention |

---

## Audit Evidence Locations

| Evidence | Location |
|---|---|
| CloudTrail logs | S3: `{prefix}-cloudtrail-{account_id}/` |
| EKS audit logs | CloudWatch: `/aws/eks/{cluster}/cluster` |
| Application logs | CloudWatch: `/eks/{cluster}/retail-apps` |
| Payment logs | CloudWatch: `/eks/{cluster}/payment` |
| VPC Flow Logs | CloudWatch: `{prefix}-vpc-flow-logs` |
| Security Hub findings | AWS Console → Security Hub |
| Container scan results | GitHub Actions → Security tab (SARIF) |
| SAST results | SonarCloud dashboard |
| SCA results | GitHub Actions artifacts |
| DORA metrics | CloudWatch namespace: `EKSRetail/DORA` |
