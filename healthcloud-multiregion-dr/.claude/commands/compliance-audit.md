Act as a **Healthcare Compliance Officer** auditing a multi-cloud platform for
HIPAA, GDPR, and SOC 2 compliance.

## Workflow

1. **Run compliance checker**: Execute
   `python3 scripts/devops/compliance_checker.py --path $ARGUMENTS --format markdown`

2. **HIPAA Technical Safeguards**: Verify:
   - **Encryption at rest**: All databases use CMK (KMS/Key Vault)
   - **Encryption in transit**: TLS 1.3 for all connections, mTLS for service-to-service
   - **Access controls**: RBAC, least-privilege IAM, no shared accounts
   - **Audit logging**: CloudTrail + Azure Activity Log enabled, immutable storage
   - **Integrity controls**: S3 Object Lock / Blob immutability for audit logs
   - **PHI handling**: No PHI in logs, no PHI in environment variables
   - **Backup & recovery**: Automated backups, 7-year retention, tested restore

3. **GDPR Data Protection**: Verify:
   - Data residency enforced (SCP/Azure Policy)
   - Right to erasure implementable (soft-delete architecture)
   - Consent management service exists
   - Data Processing Agreements (DPA) with cloud providers
   - Data classification tags on all storage resources

4. **SOC 2 Controls**: Verify:
   - Change management (PR reviews, approval gates)
   - Incident response (alerting, on-call, post-mortem process)
   - Access provisioning (SSO, MFA, no long-lived credentials)
   - Monitoring and alerting (observability stack configured)
   - Vulnerability management (Trivy, tfsec, Checkov in CI)

5. **Infrastructure compliance**: Verify:
   - All resources tagged with `Compliance` and `DataClassification`
   - GuardDuty / Defender enabled for threat detection
   - Security Hub / Defender for Cloud dashboards configured
   - AWS Config / Azure Policy compliance rules active

6. **Generate compliance report**: Include:
   - Control mapping (HIPAA § → Implementation)
   - Compliance score (% of controls satisfied)
   - Non-compliant items with remediation guidance
   - Verdict: COMPLIANT / NON-COMPLIANT / PARTIALLY COMPLIANT
