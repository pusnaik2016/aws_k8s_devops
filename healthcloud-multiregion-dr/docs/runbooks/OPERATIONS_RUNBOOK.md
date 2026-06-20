# HealthCloud — Operations Runbook

## Table of Contents
1. [Day-to-Day Operations](#1-day-to-day-operations)
2. [Cluster Access](#2-cluster-access)
3. [Deployment Procedures](#3-deployment-procedures)
4. [Scaling Operations](#4-scaling-operations)
5. [DR Failover Procedures](#5-dr-failover-procedures)
6. [Incident Response](#6-incident-response)
7. [Monitoring & Alerting](#7-monitoring--alerting)
8. [Backup & Recovery](#8-backup--recovery)
9. [Secret Management](#9-secret-management)
10. [Maintenance Windows](#10-maintenance-windows)
11. [Troubleshooting Guide](#11-troubleshooting-guide)

---

## 1. Day-to-Day Operations

### 1.1 Daily Checklist

| # | Task | Command / Tool | Frequency |
|---|------|---------------|-----------|
| 1 | Health check (both clouds) | `./scripts/ops/health-check.sh prod` | Daily 9 AM |
| 2 | Review nightly security scan | GitHub Actions → Artifacts | Daily |
| 3 | Check Aurora replication lag | CloudWatch → AuroraReplicaLag | Daily |
| 4 | Review GuardDuty findings | AWS Console → GuardDuty | Daily |
| 5 | Check Defender for Cloud score | Azure Portal → Defender | Daily |
| 6 | Review ArgoCD sync status | ArgoCD UI | Daily |

### 1.2 Weekly Checklist

| # | Task | Frequency |
|---|------|-----------|
| 1 | Review CloudTrail audit logs | Weekly |
| 2 | Validate backup integrity (test restore) | Weekly |
| 3 | Review cost reports (AWS Cost Explorer, Azure Cost Mgmt) | Weekly |
| 4 | Check certificate expiry (TLS certs) | Weekly |
| 5 | Review and merge Dependabot PRs | Weekly |

### 1.3 Monthly Checklist

| # | Task | Frequency |
|---|------|-----------|
| 1 | DR failover test | Monthly (1st of month, 4 AM UTC) |
| 2 | Secret rotation | Monthly |
| 3 | Kubernetes version review | Monthly |
| 4 | Security compliance audit | Monthly |
| 5 | Capacity planning review | Monthly |

---

## 2. Cluster Access

### 2.1 AWS EKS Access

```bash
# Configure kubectl for EKS
aws eks update-kubeconfig \
    --name healthcloud-prod-eks \
    --region us-east-1 \
    --alias aws-prod

# Verify access
kubectl --context aws-prod get nodes
kubectl --context aws-prod get pods -n healthcloud-apps
```

### 2.2 Azure AKS Access

```bash
# Configure kubectl for AKS
az aks get-credentials \
    --name healthcloud-prod-aks \
    --resource-group healthcloud-prod-aks-rg \
    --context azure-prod

# Verify access
kubectl --context azure-prod get nodes
kubectl --context azure-prod get pods -n healthcloud-apps
```

### 2.3 Database Access

```bash
# Aurora PostgreSQL (via bastion or VPN)
psql -h healthcloud-prod-aurora-primary.cluster-xxx.us-east-1.rds.amazonaws.com \
     -U healthcloud_admin \
     -d healthcloud \
     --set=sslmode=require

# Azure PostgreSQL
psql -h healthcloud-prod-pg-dr.postgres.database.azure.com \
     -U healthcloud_admin \
     -d healthcloud \
     --set=sslmode=require
```

> ⚠️ **NEVER** connect to production databases without a valid ticket and approval. All access is logged via CloudTrail/Azure Activity Log.

---

## 3. Deployment Procedures

### 3.1 Application Deployment (GitOps)

Deployments are fully automated via ArgoCD GitOps:

```
1. Developer creates feature branch
2. Developer opens PR → triggers CI pipeline:
   - Security scan (sec_scanner.py)
   - Docker build + Trivy scan
   - K8s manifest validation
3. PR approved and merged to main
4. CI pipeline builds & pushes to ECR + ACR
5. CI updates K8s manifest image tags
6. ArgoCD detects change → syncs to both clusters
7. Canary/rolling update executes
8. Health checks verify pods ready
```

**Manual override (emergency):**
```bash
# Force sync ArgoCD app
argocd app sync healthcloud-aws-apps --force --prune

# Check sync status
argocd app get healthcloud-aws-apps
```

### 3.2 Infrastructure Deployment

```bash
# 1. Initialize Terraform (first time per environment)
cd terraform/environments/prod
terraform init -backend-config=backend.hcl

# 2. Plan changes
terraform plan -var-file=terraform.tfvars -out=tfplan

# 3. Review plan carefully
terraform show tfplan

# 4. Apply (requires approval in CI pipeline)
terraform apply tfplan

# 5. Verify
./scripts/ops/health-check.sh prod
```

### 3.3 Rollback Procedures

```bash
# Application rollback (ArgoCD)
argocd app rollback healthcloud-aws-apps <REVISION_NUMBER>

# Kubernetes rollback (direct)
kubectl --context aws-prod rollout undo deployment/patient-service-deployment -n healthcloud-apps

# Terraform rollback
cd terraform/environments/prod
terraform plan -var-file=terraform.tfvars -target=<RESOURCE> -out=rollback.tfplan
terraform apply rollback.tfplan
```

---

## 4. Scaling Operations

### 4.1 Horizontal Scaling (Applications)

```bash
# Check current HPA status
kubectl --context aws-prod get hpa -n healthcloud-apps

# Manual scale (temporary override)
kubectl --context aws-prod scale deployment/patient-service-deployment \
    --replicas=5 -n healthcloud-apps

# Note: HPA will override manual scaling within its min/max range
```

### 4.2 Vertical Scaling (Nodes)

```bash
# EKS — update node group
aws eks update-nodegroup-config \
    --cluster-name healthcloud-prod-eks \
    --nodegroup-name healthcloud-prod-main-ng \
    --scaling-config minSize=5,maxSize=15,desiredSize=5

# AKS — scale node pool
az aks nodepool scale \
    --cluster-name healthcloud-prod-aks \
    --name apps \
    --resource-group healthcloud-prod-aks-rg \
    --node-count 5
```

### 4.3 Database Scaling

```bash
# Aurora — change instance class (requires maintenance window)
aws rds modify-db-instance \
    --db-instance-identifier healthcloud-prod-aurora-instance-0 \
    --db-instance-class db.r6g.2xlarge \
    --apply-immediately

# Add Aurora read replica
aws rds create-db-instance \
    --db-instance-identifier healthcloud-prod-aurora-instance-3 \
    --db-cluster-identifier healthcloud-prod-aurora-primary \
    --db-instance-class db.r6g.xlarge \
    --engine aurora-postgresql
```

---

## 5. DR Failover Procedures

### 5.1 Pre-Failover Checklist

| # | Check | Command |
|---|-------|---------|
| 1 | Azure AKS is healthy | `az aks show --name healthcloud-prod-aks --resource-group healthcloud-prod-aks-rg` |
| 2 | Azure PostgreSQL replication lag < 15 min | Check custom CloudWatch metric |
| 3 | Azure Redis is ready | `az redis show --name healthcloud-prod-redis-dr` |
| 4 | VPN connection is active | `az network vpn-connection show --name healthcloud-prod-aws-vpn-conn` |
| 5 | ArgoCD has synced to AKS | `argocd app get healthcloud-azure-dr-apps` |

### 5.2 Failover Activation

```bash
# Option 1: Automated (recommended)
./scripts/ops/dr-failover.sh activate

# Option 2: Manual steps
# Step 1: Scale AKS
az aks scale --name healthcloud-prod-aks \
    --resource-group healthcloud-prod-aks-rg \
    --node-count 5 --nodepool-name apps

# Step 2: Promote Azure PostgreSQL
az postgres flexible-server stop-replication \
    --name healthcloud-prod-pg-dr \
    --resource-group healthcloud-prod-databases-rg

# Step 3: DNS failover happens automatically via Route 53 health checks
```

### 5.3 Failback to AWS

```bash
./scripts/ops/dr-failover.sh deactivate

# Manual steps:
# 1. Verify AWS services are healthy
# 2. Re-sync data from Azure DB to Aurora (pg_dump/restore or re-establish replication)
# 3. Route 53 automatically routes back when primary is healthy
# 4. Scale down Azure AKS to warm standby (2 nodes)
```

### 5.4 DR Test Procedure

```bash
# Run monthly DR validation (dry run)
./scripts/ops/dr-failover.sh status

# Full test via CI/CD
# Triggered automatically on 1st of every month
# Or manually: GitHub Actions → DR Failover Test → Run workflow (dry_run=true)
```

---

## 6. Incident Response

### 6.1 Severity Levels

| Severity | Definition | Response Time | Examples |
|----------|-----------|---------------|---------|
| **P1 - Critical** | Service down, PHI at risk | 15 min | Primary AWS outage, data breach |
| **P2 - High** | Degraded performance, replication lag | 30 min | DB replication > 15 min, node failures |
| **P3 - Medium** | Non-critical issue | 4 hours | Dev environment down, CI failures |
| **P4 - Low** | Cosmetic, feature request | Next business day | Dashboard improvements |

### 6.2 P1 Incident Playbook

```
1. ASSESS (0-5 min)
   - Check health dashboard: CloudWatch + Azure Monitor
   - Run: ./scripts/ops/health-check.sh prod
   - Determine if AWS or Azure specific

2. COMMUNICATE (5-10 min)
   - Post to #incident-response Slack channel
   - Page on-call engineer (PagerDuty)
   - Notify CISO if PHI potentially affected

3. MITIGATE (10-30 min)
   - If AWS down → Activate DR: ./scripts/ops/dr-failover.sh activate
   - If specific service → Rollback: argocd app rollback <app>
   - If database → Check connections, failover Aurora

4. RESOLVE (30 min+)
   - Fix root cause
   - Verify health: ./scripts/ops/health-check.sh prod
   - Run compliance check: python3 scripts/devops/compliance_checker.py --path .

5. POST-MORTEM (within 48 hours)
   - Document incident timeline
   - Identify root cause
   - Create action items
   - Update runbook if needed
```

---

## 7. Monitoring & Alerting

### 7.1 Key Dashboards

| Dashboard | URL/Location | Purpose |
|-----------|-------------|---------|
| CloudWatch Overview | AWS Console → CloudWatch → healthcloud-prod-overview | EKS, Aurora, DR health |
| Azure Monitor | Azure Portal → Monitor | AKS, PostgreSQL, Redis |
| ArgoCD | https://argocd.healthcloud.example.com | GitOps sync status |
| Grafana | https://grafana.healthcloud.example.com | Prometheus metrics |
| Kiali | https://kiali.healthcloud.example.com | Istio service mesh |

### 7.2 Alert Routing

| Alert | Severity | Channel | Action |
|-------|----------|---------|--------|
| Primary endpoint down | P1 | PagerDuty + Slack + Email | Activate DR |
| Replication lag > 5 min | P2 | PagerDuty + Email | Investigate DB |
| Aurora CPU > 80% (15min) | P2 | Email | Scale DB |
| EKS node CPU > 85% | P2 | Email | Scale nodes |
| Trivy CRITICAL CVE | P3 | Slack | Patch container |
| Certificate expiry < 30d | P3 | Email | Renew cert |

---

## 8. Backup & Recovery

### 8.1 Backup Schedule

| Resource | Method | Retention | HIPAA Compliance |
|----------|--------|-----------|-----------------|
| Aurora PostgreSQL | Automated snapshots | 35 days | ✅ KMS encrypted |
| Aurora | Cross-region snapshot copy | 35 days | ✅ Encrypted |
| S3 PHI Data | Versioning + Object Lock | 7 years | ✅ WORM, KMS |
| Azure PostgreSQL | Automated backup | 35 days | ✅ Geo-redundant |
| Azure Blob | Soft delete + versioning | 365 days | ✅ CMK encrypted |
| EKS/AKS config | etcd backup (managed) | 30 days | ✅ Managed by provider |
| Terraform state | S3/Azure Storage versioned | Unlimited | ✅ Encrypted |

### 8.2 Recovery Procedures

```bash
# Aurora point-in-time recovery
aws rds restore-db-cluster-to-point-in-time \
    --source-db-cluster-identifier healthcloud-prod-aurora-primary \
    --db-cluster-identifier healthcloud-prod-aurora-restored \
    --restore-to-time "2026-06-01T00:00:00Z" \
    --kms-key-id alias/healthcloud-prod-cmk

# S3 object recovery (from versioning)
aws s3api list-object-versions \
    --bucket healthcloud-prod-phi-data-ACCOUNT_ID \
    --prefix patient-records/

# Terraform state recovery
aws s3api list-object-versions \
    --bucket healthcloud-prod-terraform-state \
    --prefix healthcloud/prod/terraform.tfstate
```

---

## 9. Secret Management

### 9.1 Secret Rotation

```bash
# Monthly rotation (recommended)
./scripts/ops/rotate-secrets.sh prod

# Emergency rotation (after suspected compromise)
./scripts/ops/rotate-secrets.sh prod
# Then immediately:
kubectl --context aws-prod rollout restart deployment -n healthcloud-apps
kubectl --context azure-prod rollout restart deployment -n healthcloud-apps
```

### 9.2 Secret Storage

| Secret | AWS | Azure |
|--------|-----|-------|
| DB password | Secrets Manager | Key Vault |
| Redis token | Secrets Manager | Key Vault |
| TLS certificates | ACM | Key Vault |
| API keys | Secrets Manager | Key Vault |
| OIDC config | IAM OIDC Provider | AAD App Registration |

---

## 10. Maintenance Windows

| Environment | Window | Duration | Approval |
|-------------|--------|----------|----------|
| Dev | Anytime | — | Self-service |
| Staging | Mon-Fri 6-8 PM EST | 2 hours | Team lead |
| Prod | Sunday 2-6 AM EST | 4 hours | CAB approval |

### 10.1 Kubernetes Upgrade Procedure

```bash
# 1. Upgrade staging first
aws eks update-cluster-version --name healthcloud-staging-eks --kubernetes-version 1.31

# 2. Wait for upgrade to complete
aws eks wait cluster-active --name healthcloud-staging-eks

# 3. Update node group
aws eks update-nodegroup-version --cluster-name healthcloud-staging-eks \
    --nodegroup-name healthcloud-staging-main-ng

# 4. Validate staging
./scripts/ops/health-check.sh staging

# 5. Repeat for prod during maintenance window
```

---

## 11. Troubleshooting Guide

### 11.1 Pod CrashLoopBackOff

```bash
# Check pod status
kubectl --context aws-prod describe pod <POD_NAME> -n healthcloud-apps

# Check logs
kubectl --context aws-prod logs <POD_NAME> -n healthcloud-apps --previous

# Common causes:
# - Database connection failed → Check security group, secrets
# - OOM killed → Increase memory limits
# - Readiness probe failed → Check /actuator/health endpoint
```

### 11.2 High Database Latency

```bash
# Check Aurora performance insights
aws pi get-resource-metrics \
    --service-type RDS \
    --identifier db-INSTANCE_ID \
    --metric-queries '[{"Metric": "db.load.avg"}]' \
    --start-time $(date -d '-1 hour' -Iseconds) \
    --end-time $(date -Iseconds)

# Check active connections
psql -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';"

# Common causes:
# - Missing indexes → Check pg_stat_user_tables for sequential scans
# - Connection pool exhaustion → Check HikariCP settings
# - Lock contention → Check pg_stat_activity for waiting queries
```

### 11.3 ArgoCD Out of Sync

```bash
# Check sync status
argocd app get healthcloud-aws-apps

# Force refresh
argocd app get healthcloud-aws-apps --refresh

# Hard reset (last resort)
argocd app sync healthcloud-aws-apps --force --replace
```
