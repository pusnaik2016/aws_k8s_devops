# ADR-004: Compliance Framework — Preventive + Detective + Responsive

| Field | Value |
|-------|-------|
| **Status** | Accepted |
| **Date** | 2024-02-01 |
| **Decision Makers** | Pushparaj Naik |

---

## Context

OmniPresenseAI handles customer support conversations that may contain PII (Personally Identifiable Information) and potentially PHI (Protected Health Information). The platform needs to comply with multiple regulatory frameworks:

- **HIPAA** — if handling health-related customer support
- **PCI-DSS** — if payment card data appears in conversations
- **SOX** — for financial audit trail integrity
- **GDPR** — for EU customer data protection

We needed to decide on a compliance approach: minimal checkbox compliance vs. defense-in-depth.

---

## Decision

We adopted a **three-layer compliance framework** using AWS-native services:

1. **Preventive controls** — stop violations before they happen
2. **Detective controls** — detect violations in near real-time
3. **Responsive controls** — automatically alert and remediate

---

## Rationale

### 1. Why Three Layers (Not Just Preventive)

Preventive controls alone are insufficient:
- WAF blocks known attack patterns but not zero-days
- KMS encrypts data but doesn't detect unauthorized access
- IRSA limits permissions but doesn't detect credential misuse

By adding detective and responsive layers, we create defense-in-depth:

| Layer | Controls | Purpose |
|-------|----------|---------|
| **Preventive** | WAF, KMS, IRSA, SGs, Bedrock Guardrails, TLS | Stop bad things from happening |
| **Detective** | GuardDuty, Security Hub, AWS Config, Macie, CloudTrail, Access Analyzer | Find bad things that got through |
| **Responsive** | SNS alerts, auto-rollback, budget alerts | React to findings immediately |

### 2. Why AWS-Native Services (Not Third-Party)

| Consideration | AWS-Native | Third-Party (Datadog/Splunk/etc.) |
|--------------|------------|----------------------------------|
| Integration effort | Terraform-native | Custom integrations needed |
| Compliance mapping | Built-in standards (CIS, PCI, HIPAA) | Manual mapping required |
| Additional cost | ~$50-100/mo | ~$200-500/mo |
| Data residency | Data stays in AWS | May egress to vendor |
| IAM integration | Native | API key based |
| Security Hub aggregation | Automatic | Custom forwarding |

AWS-native services integrate seamlessly with our existing Terraform IaC, IRSA authentication, and KMS encryption.

### 3. Why Bedrock Guardrails for AI Compliance

Traditional compliance tools (WAF, Config) don't address AI-specific risks:
- LLM outputting PII from training data
- Users submitting sensitive data in prompts
- AI providing medical/financial/legal advice (liability)
- Prompt injection attacks

Bedrock Guardrails provides:
- **PII/PHI redaction** at the API layer (before LLM sees it)
- **Content filtering** to prevent harmful AI outputs
- **Topic blocking** to avoid regulated advice
- **Prompt attack protection** against injection

---

## Trade-offs Accepted

- **Operational overhead:** 8 compliance services to monitor (mitigated by Security Hub aggregation)
- **Cost increase:** ~$50-100/mo for compliance services
- **Deployment complexity:** Compliance module adds ~15 Terraform resources
- **Alert fatigue risk:** Multiple alert sources (mitigated by severity filtering — only HIGH/CRITICAL alerts)
- **Macie false positives:** PII detection may flag non-sensitive data (weekly scheduled scans, not real-time)

---

## Consequences

### New Infrastructure
- `terraform/modules/compliance/` — 10 files (CloudTrail, GuardDuty, Security Hub, AWS Config, Macie, WAF, Access Analyzer, Budgets)
- `terraform/modules/ai_governance/` — 4 files (Bedrock Guardrails, Bedrock Logging)
- Security Hub enabled with 3 compliance standards (AWS FSBP, CIS, PCI-DSS)
- AWS Config with 10 compliance rules
- WAF with 6 rule groups (OWASP common, SQLi, bad inputs, bot control, rate limit, geo)

### Documentation
- `docs/compliance.md` — control-to-resource mapping for all 4 frameworks
- `docs/well-architected-review.md` — 6-pillar + AI Lens assessment

### Security Improvements
- Removed `AdministratorAccess` from GitHub Actions deploy role
- Added scoped IAM policy with resource-level restrictions
- All findings aggregate in Security Hub dashboard
- Alert pipeline: Finding → EventBridge → SNS → Email (< 15 minutes)

### Audit Trail
- CloudTrail: 7-year retention (S3 → Glacier), log file validation enabled
- Bedrock invocation logs: all model calls logged to CloudWatch + S3
- AWS Config: continuous configuration change recording
