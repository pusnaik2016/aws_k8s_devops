# MedCloud Global — Operations Runbook

## Table of Contents

1. [Platform Overview & Access](#1-platform-overview--access)
2. [Day-to-Day Operations](#2-day-to-day-operations)
3. [Deployment Procedures](#3-deployment-procedures)
4. [Monitoring & Alerting](#4-monitoring--alerting)
5. [Incident Response](#5-incident-response)
6. [Disaster Recovery](#6-disaster-recovery)
7. [Scaling & Performance](#7-scaling--performance)
8. [Security Operations](#8-security-operations)
9. [Maintenance Windows](#9-maintenance-windows)
10. [Troubleshooting Guide](#10-troubleshooting-guide)

---

## 1. Platform Overview & Access

### 1.1 Cluster Access

```bash
# ─── AWS EKS ────────────────────────────────────────────────
aws eks update-kubeconfig \
  --name medcloud-prod-eks \
  --region us-east-1 \
  --alias medcloud-aws

# ─── Azure AKS ──────────────────────────────────────────────
az aks get-credentials \
  --resource-group medcloud-prod-aks-rg \
  --name medcloud-prod-aks \
  --context medcloud-azure

# ─── GCP GKE ────────────────────────────────────────────────
gcloud container clusters get-credentials medcloud-prod-gke \
  --region us-central1 \
  --project medcloud-global-platform

# ─── Switch Contexts ────────────────────────────────────────
kubectl config use-context medcloud-aws
kubectl config use-context medcloud-azure
kubectl config use-context medcloud-gcp
```

### 1.2 Key URLs & Dashboards

| Resource | URL | Access |
|----------|-----|--------|
| **ArgoCD** | `https://argocd.medcloud.internal` | SSO via Entra ID |
| **Grafana** | `https://grafana.medcloud.internal` | SSO via Entra ID |
| **Jaeger** | `https://jaeger.medcloud.internal` | SRE team only |
| **Kiali (Istio)** | `https://kiali.medcloud.internal` | SRE team only |
| **AWS Console** | `https://console.aws.amazon.com` | IAM Identity Center |
| **Azure Portal** | `https://portal.azure.com` | Entra ID |
| **GCP Console** | `https://console.cloud.google.com` | Workspace SSO |

### 1.3 On-Call Rotation

| Team | Rotation | Escalation |
|------|----------|-----------|
| **SRE Primary** | Weekly (Mon 09:00 IST → Mon 09:00 IST) | PagerDuty: `medcloud-sre-primary` |
| **SRE Secondary** | Same schedule, backup | PagerDuty: `medcloud-sre-secondary` |
| **Security** | Always on (shared across team) | PagerDuty: `medcloud-security` |
| **Engineering Lead** | Escalation only | PagerDuty: `medcloud-eng-lead` |

---

## 2. Day-to-Day Operations

### 2.1 Daily Health Checks

```bash
#!/bin/bash
# Run this script daily or automate via cron

echo "═══ MedCloud Daily Health Check ═══"
echo ""

# Check all clusters
for ctx in medcloud-aws medcloud-azure medcloud-gcp; do
  echo "── Cluster: $ctx ──"
  kubectl --context=$ctx get nodes -o wide | head -5
  kubectl --context=$ctx -n medcloud get pods --field-selector=status.phase!=Running 2>/dev/null
  kubectl --context=$ctx -n medcloud top pods --sort-by=cpu | head -5
  echo ""
done

# Check ArgoCD sync status
echo "── ArgoCD Applications ──"
for ctx in medcloud-aws medcloud-azure medcloud-gcp; do
  kubectl --context=$ctx -n argocd get applications \
    -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status'
done

# Check Istio mesh health
echo "── Istio Mesh ──"
for ctx in medcloud-aws medcloud-azure medcloud-gcp; do
  kubectl --context=$ctx -n medcloud get vs,dr,authpolicy --no-headers 2>/dev/null | wc -l
done

# Check certificate expiry
echo "── Certificate Expiry ──"
for ctx in medcloud-aws medcloud-azure medcloud-gcp; do
  kubectl --context=$ctx -n istio-system get secret \
    -o jsonpath='{.items[?(@.type=="kubernetes.io/tls")].metadata.name}'
done
```

### 2.2 Key Metrics to Monitor

| Metric | Healthy | Warning | Critical |
|--------|---------|---------|----------|
| **Pod Restart Count** | 0 restarts/hr | > 3 restarts/hr | > 10 restarts/hr |
| **Error Rate (5xx)** | < 0.1% | > 1% | > 5% |
| **Latency p99** | < 500ms | > 1s | > 3s |
| **CPU Utilization** | < 60% | > 75% | > 90% |
| **Memory Utilization** | < 70% | > 80% | > 95% |
| **Node Count** | Within autoscaler range | At max | At max + pending pods |
| **Aurora Connections** | < 70% of max | > 85% | > 95% |
| **Cosmos DB RU Consumption** | < 70% provisioned | > 85% | > 95% with throttling |
| **Redis Memory** | < 60% | > 80% | > 90% |

---

## 3. Deployment Procedures

### 3.1 Standard Deployment (GitOps)

```
DEPLOYMENT FLOW:

1. Developer creates PR with changes
2. CI pipeline runs:
   a. Unit tests
   b. Container build + Trivy scan
   c. tfsec + Checkov (for infra changes)
3. PR approved and merged to main
4. ArgoCD auto-syncs within 3 minutes
5. Rolling update with zero-downtime

VERIFY:
  kubectl -n argocd get app <service-name> -o yaml | grep -A5 status
```

### 3.2 Emergency Deployment (Hotfix)

```bash
# 1. Create hotfix branch from main
git checkout -b hotfix/critical-fix main

# 2. Make changes, push, create PR
git push origin hotfix/critical-fix

# 3. Fast-track PR (requires 1 approval from SRE)
# 4. Merge to main
# 5. ArgoCD auto-syncs

# If ArgoCD is too slow, manual sync:
argocd app sync <service-name> --prune --force
```

### 3.3 Rollback Procedure

```bash
# ─── Option 1: ArgoCD Rollback ──────────────────────────────
argocd app history <service-name>
argocd app rollback <service-name> <revision-number>

# ─── Option 2: Kubernetes Rollback ──────────────────────────
kubectl -n medcloud rollout undo deployment/<service-name>
kubectl -n medcloud rollout status deployment/<service-name>

# ─── Option 3: Terraform Rollback (Infrastructure) ──────────
# Revert the git commit, then:
cd terraform/aws/networking
terraform plan -var-file=../../environments/prod/terraform.tfvars
terraform apply  # After review
```

### 3.4 Canary Deployment (Istio)

```yaml
# Apply Istio VirtualService for canary
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: storefront-api-canary
  namespace: medcloud
spec:
  hosts:
    - storefront-api
  http:
    - match:
        - headers:
            x-canary:
              exact: "true"
      route:
        - destination:
            host: storefront-api
            subset: canary
    - route:
        - destination:
            host: storefront-api
            subset: stable
          weight: 90
        - destination:
            host: storefront-api
            subset: canary
          weight: 10
```

---

## 4. Monitoring & Alerting

### 4.1 Grafana Dashboard Overview

| Dashboard | Purpose | Key Panels |
|-----------|---------|------------|
| **Platform Overview** | Cross-cloud health at a glance | Cluster status, pod counts, error rates |
| **Service Mesh** | Istio traffic flow | Request rates, latency heatmaps, mTLS status |
| **Database Health** | All databases across clouds | Connections, query latency, replication lag |
| **Security Posture** | Security findings | GuardDuty alerts, Defender findings, SCC issues |
| **Cost Tracker** | FinOps per cloud | Daily spend, forecast, anomalies |
| **SLO Dashboard** | SLI/SLO tracking | Error budgets, availability, latency targets |

### 4.2 Alert Rules (Prometheus)

```yaml
# Critical: Service completely down
- alert: ServiceDown
  expr: up{namespace="medcloud"} == 0
  for: 2m
  labels:
    severity: critical
    team: sre
  annotations:
    summary: "{{ $labels.app }} is down"
    runbook: "https://runbook.medcloud.internal/service-down"

# High: Error rate spike
- alert: HighErrorRate
  expr: |
    sum(rate(http_requests_total{namespace="medcloud",status=~"5.."}[5m]))
    /
    sum(rate(http_requests_total{namespace="medcloud"}[5m])) > 0.05
  for: 5m
  labels:
    severity: high
  annotations:
    summary: "Error rate > 5% for {{ $labels.app }}"

# High: Latency degradation
- alert: HighLatency
  expr: |
    histogram_quantile(0.99,
      sum(rate(http_request_duration_seconds_bucket{namespace="medcloud"}[5m]))
      by (le, app)
    ) > 2
  for: 5m
  labels:
    severity: high

# Warning: Pod restarts
- alert: PodRestartLoop
  expr: |
    increase(kube_pod_container_status_restarts_total{namespace="medcloud"}[1h]) > 5
  for: 10m
  labels:
    severity: warning

# Warning: Database connection exhaustion
- alert: AuroraConnectionsHigh
  expr: aws_rds_database_connections_average > 400
  for: 10m
  labels:
    severity: warning
    cloud: aws
```

---

## 5. Incident Response

### 5.1 Severity Classification

| Severity | Definition | Response | Comms |
|----------|-----------|----------|-------|
| **SEV-1** | Complete outage, data breach, PHI exposure | Immediate war room, all-hands | Status page, exec notification |
| **SEV-2** | Partial outage, degraded performance > 50% users | On-call SRE + eng lead | Status page update |
| **SEV-3** | Minor degradation, < 10% users affected | On-call SRE investigates | Slack channel update |
| **SEV-4** | Non-customer-facing, internal tooling issue | Next business day | Team Slack |

### 5.2 Incident Response Checklist

```
□ 1. DETECT — Alert received via PagerDuty
□ 2. TRIAGE — Determine severity (SEV-1 to SEV-4)
□ 3. COMMUNICATE — Update #incident-response Slack channel
□ 4. INVESTIGATE
    □ Check Grafana dashboards (which cloud? which service?)
    □ Check ArgoCD sync status (recent deployment?)
    □ Check Istio Kiali (traffic flow anomalies?)
    □ Check logs:
        AWS:   aws logs tail /medcloud/prod/app --since 30m
        Azure: az monitor log-analytics query -w <workspace-id> --analytics-query "..."
        GCP:   gcloud logging read "resource.type=k8s_container" --limit=100
□ 5. MITIGATE
    □ Rollback if deployment-related
    □ Scale up if load-related
    □ Block traffic if security-related
□ 6. RESOLVE — Confirm service restored
□ 7. POST-MORTEM — Write incident report within 48 hours
```

### 5.3 Security Incident: PHI Exposure

```
CRITICAL PROCEDURE — HIPAA BREACH PROTOCOL:

□ 1. CONTAIN immediately — isolate affected service/database
    kubectl -n medcloud scale deployment/<service> --replicas=0
    
□ 2. PRESERVE evidence — snapshot all logs, don't delete anything
    # Snapshot Aurora
    aws rds create-db-cluster-snapshot \
      --db-cluster-identifier medcloud-prod-aurora-primary \
      --db-cluster-snapshot-identifier incident-$(date +%Y%m%d-%H%M)
    
□ 3. NOTIFY within 1 hour:
    - Security Lead (PagerDuty: medcloud-security)
    - CISO / DPO
    - Legal counsel
    
□ 4. ASSESS scope — what PHI was exposed? how many patients?

□ 5. REPORT — HIPAA requires notification within 60 days if > 500 individuals

□ 6. REMEDIATE — fix root cause, add controls to prevent recurrence
```

---

## 6. Disaster Recovery

### 6.1 Database Recovery

```bash
# ─── Aurora Point-in-Time Recovery ──────────────────────────
aws rds restore-db-cluster-to-point-in-time \
  --source-db-cluster-identifier medcloud-prod-aurora-primary \
  --db-cluster-identifier medcloud-prod-aurora-recovery \
  --restore-to-time "2024-06-01T12:00:00Z" \
  --vpc-security-group-ids sg-xxxxx \
  --db-subnet-group-name medcloud-prod-aurora-subnet-group

# ─── DynamoDB Point-in-Time Recovery ────────────────────────
aws dynamodb restore-table-to-point-in-time \
  --source-table-name medcloud-prod-user-sessions \
  --target-table-name medcloud-prod-user-sessions-recovery \
  --restore-date-time "2024-06-01T12:00:00Z"

# ─── Cosmos DB Continuous Backup Restore ────────────────────
az cosmosdb mongodb restorable-database list \
  --instance-id <cosmosdb-instance-id> \
  --location eastus

az cosmosdb restore \
  --target-database-account-name medcloud-prod-cosmosdb-recovery \
  --account-name medcloud-prod-cosmosdb \
  --restore-timestamp "2024-06-01T12:00:00Z" \
  --location eastus
```

### 6.2 Full Platform Recovery

```
FULL RECOVERY PROCEDURE (RTO: 4 hours):

Phase 1: Infrastructure (60 min)
  □ Verify Terraform state files are intact (S3/Blob/GCS)
  □ terraform init && terraform plan (all 3 clouds)
  □ terraform apply (networking → compute → databases → security)

Phase 2: Data Restore (90 min)
  □ Aurora: Restore from latest automated backup
  □ DynamoDB: Restore from PITR
  □ Cosmos DB: Restore from continuous backup
  □ Redis: Warm up from cold start (cache miss is acceptable)
  □ BigQuery: No restore needed (append-only, inherently durable)

Phase 3: Application Deploy (30 min)
  □ ArgoCD: Force sync all applications
  □ Verify all pods Running
  □ Verify Istio mesh connectivity (cross-cloud)

Phase 4: Validation (60 min)
  □ Run smoke tests against all services
  □ Verify cross-cloud communication
  □ Verify database connectivity and data integrity
  □ Check monitoring dashboards
  □ Update DNS if failover to secondary region
```

---

## 7. Scaling & Performance

### 7.1 Horizontal Scaling

```bash
# Manual HPA adjustment (temporary)
kubectl -n medcloud patch hpa storefront-api \
  -p '{"spec":{"maxReplicas":30}}'

# Cluster node scaling (AWS)
aws eks update-nodegroup-config \
  --cluster-name medcloud-prod-eks \
  --nodegroup-name medcloud-prod-eks-app-nodes \
  --scaling-config minSize=5,maxSize=20,desiredSize=10

# Cluster node scaling (Azure)
az aks nodepool update \
  --resource-group medcloud-prod-aks-rg \
  --cluster-name medcloud-prod-aks \
  --name medical \
  --min-count 3 --max-count 15

# Cluster node scaling (GCP)
gcloud container clusters resize medcloud-prod-gke \
  --node-pool analytics \
  --num-nodes 5 \
  --region us-central1
```

### 7.2 Database Scaling

```bash
# Aurora: Add read replica
aws rds create-db-instance \
  --db-instance-identifier medcloud-prod-aurora-reader-3 \
  --db-cluster-identifier medcloud-prod-aurora-primary \
  --db-instance-class db.r6g.xlarge \
  --engine aurora-postgresql

# Cosmos DB: Increase RU/s
az cosmosdb mongodb collection throughput update \
  --account-name medcloud-prod-cosmosdb \
  --database-name patient-profiles \
  --name patients \
  --max-throughput 20000

# ElastiCache: Vertical scale (requires maintenance window)
aws elasticache modify-replication-group \
  --replication-group-id medcloud-prod-redis \
  --cache-node-type cache.r6g.xlarge \
  --apply-immediately
```

---

## 8. Security Operations

### 8.1 Daily Security Checks

```bash
# Check GuardDuty findings
aws guardduty list-findings \
  --detector-id <detector-id> \
  --finding-criteria '{"Criterion":{"severity":{"Gte":7}}}' \
  --sort-criteria '{"AttributeName":"severity","OrderBy":"DESC"}'

# Check Security Hub compliance
aws securityhub get-findings \
  --filters '{"ComplianceStatus":[{"Value":"FAILED","Comparison":"EQUALS"}]}' \
  --max-items 20

# Check Azure Defender alerts
az security alert list --query "[?status=='Active']" -o table

# Check GCP Security Command Center
gcloud scc findings list organizations/<org-id> \
  --filter="state=\"ACTIVE\" AND severity=\"HIGH\""
```

### 8.2 Certificate Management

```bash
# Check Istio certificate expiry
for ctx in medcloud-aws medcloud-azure medcloud-gcp; do
  echo "── $ctx ──"
  istioctl --context=$ctx proxy-config secret \
    $(kubectl --context=$ctx -n medcloud get pod -l app=storefront-api -o name | head -1) \
    -o json | jq '.dynamicActiveSecrets[0].secret.tlsCertificate.certificateChain.inlineBytes' \
    | base64 -d | openssl x509 -noout -dates
done
```

---

## 9. Maintenance Windows

| Activity | Schedule | Duration | Impact |
|----------|----------|----------|--------|
| **K8s Version Upgrade** | Monthly (1st Saturday) | 2-4 hr | Rolling — zero downtime |
| **Aurora Maintenance** | Weekly (Saturday 04:00-05:00 UTC) | < 30 min | Brief failover |
| **Cosmos DB Updates** | Continuous (Azure managed) | 0 | None |
| **Istio Upgrade** | Quarterly | 1-2 hr | Canary upgrade — zero downtime |
| **Security Patching** | Weekly (auto) | Varies | Bottlerocket auto-update |
| **Certificate Rotation** | Auto (Istio 24hr, TLS 90-day) | 0 | None |

---

## 10. Troubleshooting Guide

### 10.1 Common Issues

#### Pod in CrashLoopBackOff

```bash
# Check logs
kubectl -n medcloud logs <pod-name> --previous

# Check events
kubectl -n medcloud describe pod <pod-name> | tail -20

# Common causes:
# - Missing secrets/configmaps
# - Database connection refused (check network policies)
# - OOM killed (check resource limits)
# - Health check failing (check endpoints)
```

#### Cross-Cloud Communication Failure

```bash
# 1. Check Istio proxy status
istioctl proxy-status

# 2. Check east-west gateway connectivity
kubectl -n istio-system get svc istio-eastwestgateway

# 3. Check VPN tunnel status
# AWS
aws ec2 describe-vpn-connections --query 'VpnConnections[*].VgwTelemetry'

# Azure
az network vpn-connection show -g medcloud-prod-networking-rg -n aws-vpn \
  --query 'connectionStatus'

# GCP
gcloud compute vpn-tunnels describe medcloud-prod-vpn-to-aws \
  --region us-central1 --format='value(status)'

# 4. Test cross-cloud DNS resolution
kubectl -n medcloud exec -it <pod> -- nslookup patient-service.medcloud.svc.cluster.local
```

#### Database Connection Issues

```bash
# Aurora — check connections
aws rds describe-db-instances \
  --db-instance-identifier medcloud-prod-aurora-0 \
  --query 'DBInstances[0].{Status:DBInstanceStatus,Connections:Endpoint}'

# Test from pod
kubectl -n medcloud exec -it <pod> -- \
  pg_isready -h <aurora-endpoint> -p 5432 -U medcloud_admin

# Cosmos DB — check from pod
kubectl -n medcloud exec -it <pod> -- \
  curl -k https://<cosmosdb-endpoint>:10255/ 2>&1 | head -5

# Redis — check connectivity
kubectl -n medcloud exec -it <pod> -- \
  redis-cli -h <redis-endpoint> -p 6379 --tls ping
```

---

**Document Version:** 1.0 | **Author:** Pushparaj Naik | **Classification:** Internal — Confidential
