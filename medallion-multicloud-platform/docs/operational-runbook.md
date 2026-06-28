# Operational Runbook

## Enterprise Multi-Cloud Medallion Data Platform

---

## 1. Day-2 Operations Overview

This runbook covers standard operational procedures for the medallion data platform across AWS (primary) and Azure (DR standby).

---

## 2. Infrastructure Operations

### 2.1 Terraform State Management

**State Storage**:
- AWS: `s3://medallion-platform-tfstate/production/terraform.tfstate`
- Azure: `medallionplatformtfstate` storage account → `tfstate` container

**Applying Infrastructure Changes**:
```bash
# Always plan before applying
cd terraform/environments/production
terraform plan -var-file=terraform.tfvars -out=plan.out

# Review the plan output carefully
terraform show plan.out

# Apply only after review
terraform apply plan.out
```

**State Lock Recovery**:
```bash
# If a lock is stuck (previous apply crashed)
terraform force-unlock <LOCK_ID>
```

### 2.2 VPC Endpoint Health Check

```bash
# Check VPC endpoint status
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=<VPC_ID>" \
  --query 'VpcEndpoints[*].[VpcEndpointId,ServiceName,State]' \
  --output table
```

Expected: All endpoints in `available` state.

### 2.3 KMS Key Rotation Verification

```bash
# Verify key rotation is enabled
aws kms get-key-rotation-status --key-id <KEY_ID>

# List all CMKs and their rotation status
aws kms list-keys --query 'Keys[*].KeyId' --output text | \
  xargs -I{} aws kms get-key-rotation-status --key-id {}
```

---

## 3. Secrets Management Operations

### 3.1 Manual Secret Rotation (Emergency)

**AWS Secrets Manager**:
```bash
# Trigger immediate rotation
aws secretsmanager rotate-secret \
  --secret-id medallion-platform-production/databricks/access-token

# Verify rotation completed
aws secretsmanager describe-secret \
  --secret-id medallion-platform-production/databricks/access-token \
  --query 'RotationEnabled,LastRotatedDate'
```

**Azure Key Vault**:
```bash
# Create new version of secret
az keyvault secret set \
  --vault-name medallionplatformproductionkv \
  --name databricks-access-token \
  --value "<NEW_VALUE>"

# Verify
az keyvault secret show \
  --vault-name medallionplatformproductionkv \
  --name databricks-access-token \
  --query '{version:id,created:attributes.created}'
```

### 3.2 Rotation Lambda Monitoring

```bash
# Check Lambda invocation logs
aws logs filter-log-events \
  --log-group-name /aws/lambda/medallion-platform-production-secrets-rotation \
  --start-time $(date -d '24 hours ago' +%s000) \
  --filter-pattern "rotation_complete"
```

---

## 4. Databricks Pipeline Operations

### 4.1 Pipeline Health Check

```bash
# List recent job runs
databricks jobs list-runs --job-id <JOB_ID> --limit 5 --output JSON

# Get specific run status
databricks runs get --run-id <RUN_ID>
```

### 4.2 Bundle Deployment

```bash
# Validate before deploying
cd databricks
databricks bundle validate -t aws_production

# Deploy to AWS Primary
databricks bundle deploy -t aws_production

# Verify deployment
databricks bundle summary -t aws_production
```

### 4.3 Pipeline Failure Triage

| Error Pattern | Likely Cause | Resolution |
|--------------|-------------|------------|
| `SecretNotFoundException` | Secret expired or rotated | Verify secret exists in scope, check rotation Lambda logs |
| `S3 Access Denied` | VPC endpoint issue or IAM policy | Check VPC endpoint status, verify IAM role permissions |
| `Schema Mismatch` | Source data schema changed | Review Auto Loader schema evolution, update `bronze_schema.json` |
| `OPTIMIZE failed` | Delta Lake version conflict | Retry after 5 minutes, check for concurrent writers |
| `KMS Decrypt Error` | KMS key disabled or access revoked | Verify KMS key status and IAM grants |

### 4.4 Data Quality Monitoring

```sql
-- Check recent DQ audit results
SELECT * FROM medallion.silver.data_quality_audit
WHERE timestamp > current_timestamp() - INTERVAL 24 HOURS
ORDER BY timestamp DESC;

-- Check for failed DQ checks
SELECT * FROM medallion.silver.data_quality_audit
WHERE status = 'FAIL'
AND timestamp > current_timestamp() - INTERVAL 7 DAYS;
```

---

## 5. Monitoring & Alerting

### 5.1 CloudWatch Dashboard

Dashboard name: `medallion-platform-production-compliance-kpis`

**Key Metrics**:
- Unauthorized API Calls (target: 0)
- Root Account Usage (target: 0)
- S3 Policy Modifications (monitor for changes)
- KMS Key Deletion Events (target: 0)

### 5.2 Alert Response Procedures

| Alert | Severity | Response |
|-------|----------|----------|
| Unauthorized API Calls | HIGH | Investigate caller identity in CloudTrail, verify IAM policies, check for compromised credentials |
| Root Account Usage | CRITICAL | Immediately verify legitimacy, rotate root credentials if unauthorized, file incident report |
| S3 Policy Change | MEDIUM | Verify change was authorized via CI/CD, check encryption and public access settings |
| KMS Key Deletion | CRITICAL | Cancel deletion if unauthorized (`aws kms cancel-key-deletion`), investigate who initiated |
| Key Vault Unauthorized | HIGH | Review Azure AD sign-in logs, verify network ACL rules, check managed identity bindings |

### 5.3 Log Analysis Queries

**AWS CloudTrail — Failed authentication attempts**:
```bash
aws logs filter-log-events \
  --log-group-name /aws/cloudtrail/medallion-platform-production \
  --filter-pattern '{ $.errorCode = "AccessDenied" }' \
  --start-time $(date -d '1 hour ago' +%s000)
```

**Azure Log Analytics — Key Vault audit**:
```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.KEYVAULT"
| where TimeGenerated > ago(24h)
| summarize count() by OperationName, ResultSignature
| order by count_ desc
```

---

## 6. Compliance Audit Procedures

### 6.1 Monthly Compliance Check

```bash
# 1. Verify all S3 buckets have CMK encryption
aws s3api list-buckets --query 'Buckets[*].Name' --output text | \
  xargs -I{} aws s3api get-bucket-encryption --bucket {} 2>/dev/null

# 2. Verify no public S3 buckets
aws s3api list-buckets --query 'Buckets[*].Name' --output text | \
  xargs -I{} aws s3api get-public-access-block --bucket {}

# 3. Verify CloudTrail is logging
aws cloudtrail get-trail-status --name medallion-platform-production-audit-trail

# 4. Verify secrets rotation is active
aws secretsmanager list-secrets \
  --query 'SecretList[*].[Name,RotationEnabled,LastRotatedDate]' \
  --output table

# 5. Check AWS Config compliance
aws configservice get-compliance-summary-by-config-rule
```

### 6.2 Quarterly Encryption Key Audit

1. Verify KMS key rotation status for all 3 CMKs
2. Verify Key Vault key rotation policies are active
3. Review key access logs in CloudTrail / Key Vault diagnostics
4. Confirm no keys are scheduled for deletion
5. Document findings in compliance audit report

---

## 7. Scaling Operations

### 7.1 Increase Databricks Cluster Size

Update the cluster policy in `aws-databricks/main.tf`:
```hcl
"driver_node_type_id" = {
  type = "allowlist"
  values = ["m5.xlarge", "m5.2xlarge", "m5.4xlarge", "m5.8xlarge"]  # Add larger instance
}
```

### 7.2 Increase SQL Warehouse Capacity

```hcl
resource "databricks_sql_endpoint" "gold_analytics" {
  cluster_size     = "Medium"     # Upgrade from Small
  max_num_clusters = 4            # Increase from 2
}
```

---

## 8. Contact & Escalation

| Level | Team | Contact | Response Time |
|-------|------|---------|---------------|
| L1 | Platform Operations | platform-ops@company.com | 15 minutes |
| L2 | Data Engineering | data-eng@company.com | 30 minutes |
| L3 | Security & Compliance | security@company.com | 1 hour |
| L4 | Cloud Architecture | cloud-arch@company.com | 2 hours |
