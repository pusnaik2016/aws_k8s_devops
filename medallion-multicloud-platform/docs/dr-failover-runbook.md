# Disaster Recovery Failover Runbook

## Enterprise Multi-Cloud Medallion Data Platform

**Pattern**: Active-Passive Pilot Light  
**Primary**: AWS (us-east-1)  
**DR Site**: Azure (eastus2)  
**RTO Target**: 4 hours  
**RPO Target**: 1 hour  

---

## 1. DR Architecture Summary

```
NORMAL OPERATION:
  AWS Primary (ACTIVE) ──[DirectConnect]──▶ Azure DR (STANDBY)
  • Pipelines: RUNNING                     • Pipelines: PAUSED
  • Compute: ACTIVE                        • Compute: MINIMAL
  • Data: LIVE                             • Data: REPLICATED

FAILOVER ACTIVATED:
  AWS Primary (DEGRADED) ──[VPN Failover]──▶ Azure DR (ACTIVE)
  • Pipelines: STOPPED                      • Pipelines: UNPAUSED
  • Compute: ISOLATED                       • Compute: SCALING UP
  • Data: STALE                             • Data: SERVING
```

---

## 2. Failover Decision Matrix

| Scenario | Impact | Action |
|----------|--------|--------|
| Single AZ failure in AWS | Partial — HA covers | Monitor, no failover |
| AWS region outage (us-east-1) | Full primary loss | **INITIATE DR FAILOVER** |
| Databricks control plane outage | Pipeline stopped | Wait for resolution (4h), then failover |
| S3 service degradation | Data access impaired | Wait for resolution (2h), then failover |
| DirectConnect failure only | Replication stopped | Activate VPN failover, no DR switch |
| Security breach on AWS | Active compromise | **ISOLATE AWS, INITIATE DR FAILOVER** |

---

## 3. Pre-Failover Checklist

Before initiating failover, verify:

- [ ] Azure DR infrastructure is provisioned (Terraform state is current)
- [ ] ADLS Gen2 data replication is recent (check last sync timestamp)
- [ ] Key Vault secrets are current (check expiration dates)
- [ ] Databricks workspace is accessible (Azure portal → workspace health)
- [ ] ExpressRoute/VPN tunnel is operational (or VPN failover is active)
- [ ] DR Databricks bundle is deployed (check `azure_dr_standby` target)
- [ ] Communication sent to stakeholders (Slack/email notification)

---

## 4. Failover Procedure

### Phase 1: Assessment (0-30 minutes)

```bash
# 1. Verify AWS primary is actually down
aws sts get-caller-identity 2>/dev/null || echo "AWS UNREACHABLE"
aws s3 ls s3://medallion-platform-production-bronze-landing/ 2>/dev/null || echo "S3 UNREACHABLE"

# 2. Check Azure DR readiness
az account show
az storage account show --name medallionplatformdrstandbydl --query "statusOfPrimary"
az databricks workspace show --name medallion-platform-dr-standby-dbx-workspace \
  --resource-group medallion-platform-dr-standby-databricks-rg
```

### Phase 2: Activate Azure DR (30 min - 2 hours)

```bash
# Step 1: Verify network connectivity
# If DirectConnect is down, VPN should auto-failover
az network vpn-connection show \
  --name medallion-platform-dr-standby-vpn-aws-tunnel1 \
  --resource-group medallion-platform-dr-standby-transit-rg \
  --query "connectionStatus"

# Step 2: Verify Key Vault secrets are accessible
az keyvault secret list --vault-name medallionplatformdrstandbykv --query "[].id"

# Step 3: Verify ADLS Gen2 data is accessible
az storage blob list \
  --account-name medallionplatformdrstandbydl \
  --container-name bronze \
  --num-results 5

# Step 4: Unpause Databricks pipeline schedules
# Option A: Via Databricks CLI
cd databricks
databricks bundle deploy -t azure_dr_standby  # Redeploy if needed

# Option B: Via Databricks REST API
curl -X PATCH "https://azure-dr.azuredatabricks.net/api/2.1/jobs/update" \
  -H "Authorization: Bearer $(az keyvault secret show --vault-name medallionplatformdrstandbykv --name databricks-access-token --query value -o tsv)" \
  -d '{
    "job_id": "<JOB_ID>",
    "new_settings": {
      "schedule": {
        "quartz_cron_expression": "0 0 */2 * * ?",
        "timezone_id": "UTC",
        "pause_status": "UNPAUSED"
      }
    }
  }'

# Step 5: Trigger an immediate pipeline run to validate
databricks jobs run-now --job-id <JOB_ID>
```

### Phase 3: Validation (2-3 hours)

```bash
# 1. Verify pipeline completed successfully
databricks runs get --run-id <RUN_ID> --query state

# 2. Verify data was written to DR tables
# Connect to Azure Databricks and run:
```

```sql
-- Verify Bronze data exists
SELECT COUNT(*) as bronze_count FROM medallion.bronze.raw_events;

-- Verify Silver transformation ran
SELECT COUNT(*) as silver_count FROM medallion.silver.cleansed_events;

-- Verify Gold aggregation produced results
SELECT * FROM medallion.gold.pipeline_metrics ORDER BY metric_timestamp DESC LIMIT 5;

-- Verify DQ audit trail
SELECT * FROM medallion.silver.data_quality_audit ORDER BY timestamp DESC LIMIT 10;
```

```bash
# 3. Verify monitoring is active
az monitor metrics list \
  --resource $(az storage account show --name medallionplatformdrstandbydl --query id -o tsv) \
  --metric Availability \
  --interval PT5M
```

### Phase 4: Stakeholder Communication (3-4 hours)

1. Send notification: "DR failover complete. Azure is now the active data platform."
2. Update DNS/endpoints if applicable
3. Update CI/CD to deploy to `azure_dr_standby` as primary target
4. Document the incident in the compliance audit log

---

## 5. Failback Procedure (AWS Recovery)

### Phase 1: AWS Recovery Verification

```bash
# 1. Confirm AWS services are restored
aws sts get-caller-identity
aws s3 ls s3://medallion-platform-production-bronze-landing/

# 2. Verify Databricks workspace is accessible
databricks workspace ls -t aws_production /

# 3. Check KMS keys are active
aws kms describe-key --key-id alias/medallion-platform-production-s3-data \
  --query 'KeyMetadata.KeyState'
```

### Phase 2: Data Sync (Azure → AWS)

```bash
# 1. Sync any new data from Azure DR back to AWS
# This depends on your replication strategy. Options:
# a) Azure Data Factory copy pipeline
# b) Databricks Delta Lake CLONE
# c) Custom PySpark sync job

# Example: Delta CLONE from Azure to AWS (run in Azure Databricks)
# spark.sql("""
#   CREATE TABLE medallion.bronze.raw_events_sync
#   DEEP CLONE delta.`abfss://bronze@medallionplatformdrstandbydl.dfs.core.windows.net/raw_events`
#   LOCATION 's3://medallion-platform-production-bronze-landing/sync/'
# """)
```

### Phase 3: Resume AWS Primary

```bash
# 1. Redeploy DAB to AWS
cd databricks
databricks bundle deploy -t aws_production

# 2. Trigger validation run
databricks jobs run-now --job-id <JOB_ID>

# 3. Pause Azure DR schedules
# Update DAB target to paused state
databricks bundle deploy -t azure_dr_standby  # Already configured as PAUSED
```

### Phase 4: Post-Failback Validation

```bash
# Verify configuration parity
databricks bundle validate -t aws_production
databricks bundle validate -t azure_dr_standby

# Run compliance checks
cd terraform/environments/production
terraform plan -var-file=terraform.tfvars  # Should show no changes
```

---

## 6. DR Testing Schedule

| Test Type | Frequency | Description |
|-----------|-----------|-------------|
| Connectivity Test | Weekly | Verify VPN/DirectConnect tunnel status |
| Data Replication Test | Weekly | Verify ADLS Gen2 data freshness |
| Bundle Validation | Every deployment | `databricks bundle validate -t azure_dr_standby` |
| Tabletop Exercise | Quarterly | Walk through failover procedure with team |
| Full DR Test | Semi-annually | Execute complete failover and failback to Azure |

---

## 7. Emergency Contacts

| Role | Name | Contact | Availability |
|------|------|---------|-------------|
| DR Commander | TBD | emergency@company.com | 24/7 on-call |
| Cloud Infra Lead | TBD | cloud-infra@company.com | Business hours + on-call |
| Data Platform Lead | TBD | data-platform@company.com | Business hours + on-call |
| Security Officer | TBD | ciso@company.com | 24/7 on-call |
| Compliance Officer | TBD | compliance@company.com | Business hours |

---

## 8. Post-Incident Review Template

After any DR activation, complete this review:

1. **Timeline**: When was the incident detected? When was failover initiated? When was service restored?
2. **Data Impact**: What was the actual RPO? Was any data lost?
3. **Root Cause**: What caused the primary site failure?
4. **Gaps Identified**: Did the runbook work as expected? What needs updating?
5. **Action Items**: List improvements with owners and deadlines
6. **Compliance Filing**: Submit incident report per HIPAA §164.308(a)(6) and SOC 2 CC7.3
