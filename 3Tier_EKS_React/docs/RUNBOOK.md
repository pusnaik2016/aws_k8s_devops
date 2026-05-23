# Operations Runbook
## 3-Tier DevOps Quiz Application on AWS EKS
**Author:** Pushparaj Naik | **Version:** 1.0 | **Date:** 2026-04-27

---

## 1. Day-to-Day Operations

### 1.1 Health Check Commands

```bash
# Cluster health
kubectl get nodes
kubectl get pods -n 3-tier-app-eks
kubectl get svc -n 3-tier-app-eks
kubectl get ingress -n 3-tier-app-eks

# Application health
kubectl logs -l app=backend -n 3-tier-app-eks --tail=50
kubectl logs -l app=frontend -n 3-tier-app-eks --tail=50

# HPA status
kubectl get hpa -n 3-tier-app-eks

# Check resource utilization
kubectl top pods -n 3-tier-app-eks
kubectl top nodes
```

### 1.2 Monitoring Access

```bash
# Grafana (default: admin/admin)
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80

# Prometheus
kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090
```

---

## 2. Deployment Procedures

### 2.1 Application Update (Rolling)

```bash
# Update backend image
kubectl set image deployment/backend \
  backend=YOUR_ECR_REPO/backend:NEW_TAG \
  -n 3-tier-app-eks

# Update frontend image
kubectl set image deployment/frontend \
  frontend=YOUR_ECR_REPO/frontend:NEW_TAG \
  -n 3-tier-app-eks

# Verify rollout
kubectl rollout status deployment/backend -n 3-tier-app-eks
kubectl rollout status deployment/frontend -n 3-tier-app-eks
```

### 2.2 Rollback

```bash
# Rollback backend
kubectl rollout undo deployment/backend -n 3-tier-app-eks

# Rollback frontend
kubectl rollout undo deployment/frontend -n 3-tier-app-eks

# Rollback to specific revision
kubectl rollout undo deployment/backend -n 3-tier-app-eks --to-revision=2

# Check rollout history
kubectl rollout history deployment/backend -n 3-tier-app-eks
```

### 2.3 Infrastructure Changes

```bash
cd infra
terraform plan -out=plan.out
# Review the plan carefully
terraform apply plan.out
```

---

## 3. Incident Response

### 3.1 Pod CrashLoopBackOff

```bash
# Check pod status
kubectl describe pod POD_NAME -n 3-tier-app-eks

# Check logs
kubectl logs POD_NAME -n 3-tier-app-eks --previous

# Common causes:
# - Database connection failure → check secrets.yaml, database-service.yaml
# - Image pull error → check ECR credentials
# - OOM killed → increase memory limits in deployment
```

### 3.2 Database Connection Issues

```bash
# Verify RDS endpoint
aws rds describe-db-instances --db-instance-identifier pushparaj-dev-db \
  --query 'DBInstances[0].Endpoint'

# Test from a pod
kubectl run db-test --rm -it --image=postgres:13-alpine \
  -n 3-tier-app-eks -- pg_isready -h YOUR_RDS_ENDPOINT -p 5432

# Check secrets
kubectl get secret app-secrets -n 3-tier-app-eks -o yaml

# Verify Security Group allows traffic from EKS subnets
aws ec2 describe-security-groups --group-ids SG_ID
```

### 3.3 Ingress/ALB Issues

```bash
# Check ingress status
kubectl describe ingress app-ingress -n 3-tier-app-eks

# Check ALB Controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Verify target group health
aws elbv2 describe-target-health --target-group-arn TG_ARN
```

### 3.4 High CPU/Memory

```bash
# Identify hot pods
kubectl top pods -n 3-tier-app-eks --sort-by=cpu

# Check HPA scaling
kubectl describe hpa backend-hpa -n 3-tier-app-eks

# Force scale
kubectl scale deployment/backend --replicas=4 -n 3-tier-app-eks
```

---

## 4. Backup & Recovery

### 4.1 Database Backup (Automated)
- **Automated Backups:** 7-day retention (configurable)
- **Backup Window:** 03:00-04:00 UTC
- **Snapshot Encryption:** KMS encrypted

```bash
# List snapshots
aws rds describe-db-snapshots \
  --db-instance-identifier pushparaj-dev-db

# Create manual snapshot
aws rds create-db-snapshot \
  --db-instance-identifier pushparaj-dev-db \
  --db-snapshot-identifier manual-$(date +%Y%m%d)

# Restore from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier pushparaj-dev-db-restored \
  --db-snapshot-identifier SNAPSHOT_ID
```

### 4.2 EKS State Backup

```bash
# Export all resources
kubectl get all -n 3-tier-app-eks -o yaml > backup-all.yaml

# Backup specific resources
kubectl get deployment,svc,configmap,secret -n 3-tier-app-eks -o yaml > backup-app.yaml
```

---

## 5. Scaling Operations

### 5.1 EKS Node Scaling

```bash
# Current nodes
kubectl get nodes

# Scale via Terraform (recommended)
# Update eks_node_desired_size in terraform.tfvars
cd infra && terraform apply

# Or via AWS CLI (emergency)
aws eks update-nodegroup-config \
  --cluster-name pushparaj-dev-cluster \
  --nodegroup-name primary \
  --scaling-config minSize=2,maxSize=5,desiredSize=3
```

### 5.2 Application Scaling

```bash
# Scale deployments
kubectl scale deployment/backend --replicas=4 -n 3-tier-app-eks
kubectl scale deployment/frontend --replicas=4 -n 3-tier-app-eks

# Update HPA
kubectl patch hpa backend-hpa -n 3-tier-app-eks \
  -p '{"spec":{"maxReplicas":10}}'
```

---

## 6. Security Operations

### 6.1 Rotate Database Password

```bash
# 1. Generate new password
NEW_PASS=$(openssl rand -base64 16)

# 2. Update RDS
aws rds modify-db-instance \
  --db-instance-identifier pushparaj-dev-db \
  --master-user-password "$NEW_PASS"

# 3. Update Secrets Manager
aws secretsmanager update-secret \
  --secret-id db/pushparaj-dev-db \
  --secret-string '{"password":"'$NEW_PASS'"}'

# 4. Update K8s secret
echo -n "$NEW_PASS" | base64
# Update secrets.yaml and apply
kubectl apply -f k8s/secrets.yaml

# 5. Restart backend pods
kubectl rollout restart deployment/backend -n 3-tier-app-eks
```

### 6.2 Review GuardDuty Findings

```bash
aws guardduty list-findings --detector-id DETECTOR_ID
aws guardduty get-findings --detector-id DETECTOR_ID --finding-ids FINDING_ID
```

### 6.3 Review CloudTrail Events

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ConsoleLogin \
  --max-results 10
```

---

## 7. Disaster Recovery Runbook

### 7.1 DR Activation (Failover)

1. **Assess** — Confirm primary region failure
2. **Database** — Restore from latest cross-region snapshot in us-east-1
3. **Infrastructure** — Run Terraform in DR region:
   ```bash
   cd infra
   terraform init
   terraform apply -var="aws_region=us-east-1"
   ```
4. **Application** — Deploy K8s manifests to new cluster
5. **DNS** — Update Route53 to point to DR region ALB
6. **Validate** — Run health checks

### 7.2 DR Deactivation (Failback)

1. Confirm primary region recovery
2. Sync data from DR to primary
3. Re-deploy in primary region
4. Switch DNS back
5. Decommission DR infrastructure

---

## 8. Maintenance Windows

| Task | Window | Frequency |
|------|--------|-----------|
| RDS Maintenance | Sun 04:00-05:00 UTC | As needed |
| RDS Backups | 03:00-04:00 UTC | Daily |
| EKS Version Upgrade | Planned | Quarterly |
| KMS Key Rotation | Automatic | Annually |
| Certificate Renewal | Automatic (cert-manager) | 90 days |
| Security Patching | Sun 02:00-06:00 UTC | Monthly |

---

## 9. Contacts & Escalation

| Level | Contact | Response Time |
|-------|---------|--------------|
| L1 — On-call | Pushparaj Naik | < 15 min |
| L2 — DevOps | DevOps Team | < 1 hour |
| L3 — AWS Support | AWS Premium Support | < 4 hours |
