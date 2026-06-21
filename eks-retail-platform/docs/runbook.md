# Operations Runbook — EKS Retail Platform

## Table of Contents
1. [Day-2 Operations](#day-2-operations)
2. [Scaling Operations](#scaling-operations)
3. [Incident Response](#incident-response)
4. [Troubleshooting](#troubleshooting)
5. [Maintenance Procedures](#maintenance-procedures)
6. [Disaster Recovery](#disaster-recovery)

---

## Day-2 Operations

### Cluster Access
```bash
# Configure kubectl
aws eks update-kubeconfig --name eks-retail-${ENV}-eks --region us-east-1

# Verify access
kubectl cluster-info
kubectl get nodes -o wide
```

### Health Checks
```bash
# Cluster status
kubectl get cs                     # Component status
kubectl get nodes                  # Node health
kubectl top nodes                  # Node resource usage

# Workload status
kubectl get pods -n retail-apps    # App pods
kubectl get pods -n payment        # Payment pods (PCI)
kubectl get pods -n keda           # KEDA operator
kubectl get pods -n istio-system   # Istio

# Autoscaler status
kubectl get hpa -A                 # All HPAs
kubectl get scaledobjects -n retail-apps  # KEDA objects
kubectl get nodepools              # Karpenter NodePools
kubectl get nodeclaims             # Karpenter provisioned nodes
```

### ArgoCD Operations
```bash
# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Port-forward ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Sync application manually
argocd app sync storefront-api
argocd app sync retail-platform --prune  # Full sync

# Check sync status
argocd app list
argocd app get storefront-api
```

### Log Access
```bash
# View pod logs
kubectl logs -f deployment/storefront-api -n retail-apps

# View FluentBit logs
kubectl logs -f daemonset/fluentbit -n fluentbit

# CloudWatch Insights query (via AWS CLI)
aws logs start-query \
  --log-group-name "/eks/eks-retail-prod-eks/retail-apps" \
  --start-time $(date -d '1 hour ago' +%s) \
  --end-time $(date +%s) \
  --query-string 'fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 50'
```

---

## Scaling Operations

### Manual Scaling
```bash
# Scale deployment manually
kubectl scale deployment storefront-api -n retail-apps --replicas=5

# Override KEDA (pause autoscaling)
kubectl annotate scaledobject order-service-scaler \
  autoscaling.keda.sh/paused="true" -n retail-apps

# Resume KEDA
kubectl annotate scaledobject order-service-scaler \
  autoscaling.keda.sh/paused- -n retail-apps
```

### Karpenter Node Management
```bash
# View provisioned nodes
kubectl get nodeclaims -o wide

# Force node consolidation
kubectl delete nodeclaim <name>  # Karpenter will repack pods

# Drain a specific node
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Check spot interruption queue
aws sqs get-queue-attributes \
  --queue-url https://sqs.us-east-1.amazonaws.com/<account>/eks-retail-prod-karpenter-interruption \
  --attribute-names ApproximateNumberOfMessagesVisible
```

### SQS Queue Management
```bash
# Check queue depth (KEDA trigger)
aws sqs get-queue-attributes \
  --queue-url <ORDER_QUEUE_URL> \
  --attribute-names ApproximateNumberOfMessagesVisible,ApproximateNumberOfMessagesNotVisible

# Purge DLQ (after investigation)
aws sqs purge-queue --queue-url <DLQ_URL>

# Redrive DLQ messages
aws sqs start-message-move-task \
  --source-arn <DLQ_ARN> \
  --destination-arn <MAIN_QUEUE_ARN>
```

---

## Incident Response

### Severity Levels
| Level | Description | Response Time | Examples |
|---|---|---|---|
| **SEV1** | Complete service outage | 15 min | EKS API unreachable, all pods down |
| **SEV2** | Partial degradation | 30 min | Payment failures, high error rate |
| **SEV3** | Performance issue | 2 hours | Elevated latency, scaling issues |
| **SEV4** | Non-impacting | Next business day | Security finding, log alert |

### SEV1: Complete Outage
```bash
# 1. Check EKS cluster health
aws eks describe-cluster --name eks-retail-prod-eks --query 'cluster.status'

# 2. Check node health
kubectl get nodes
kubectl describe node <unhealthy-node>

# 3. Check system pods
kubectl get pods -n kube-system
kubectl get pods -n istio-system

# 4. Check Karpenter
kubectl logs -n kube-system deployment/karpenter --tail=100

# 5. Force restart problematic deployment
kubectl rollout restart deployment/<service> -n retail-apps
```

### SEV2: Payment Service Down
```bash
# 1. Check payment pods
kubectl get pods -n payment -o wide
kubectl describe pods -l app=payment-service -n payment

# 2. Check PCI node availability
kubectl get nodes -l compliance=pci-hipaa

# 3. Check Karpenter PCI NodePool
kubectl describe nodepool pci-compliant
kubectl get nodeclaims -l karpenter.sh/nodepool=pci-compliant

# 4. Check DB connectivity
kubectl exec -it deployment/payment-service -n payment -- \
  python -c "import asyncpg; print('DB OK')"

# 5. Check Istio AuthorizationPolicy
kubectl get authorizationpolicy -n payment
istioctl analyze -n payment
```

### SEV3: Autoscaling Not Working
```bash
# KEDA not scaling
kubectl describe scaledobject order-service-scaler -n retail-apps
kubectl logs -n keda deployment/keda-operator --tail=50

# HPA not scaling
kubectl describe hpa storefront-api-hpa -n retail-apps
kubectl get --raw "/apis/external.metrics.k8s.io/v1beta1" | jq .

# Karpenter not provisioning
kubectl logs -n kube-system deployment/karpenter --tail=100 | grep -i error
kubectl describe nodepool default
```

### Security Incident
```bash
# 1. Check GuardDuty findings
aws guardduty list-findings --detector-id <DETECTOR_ID> \
  --finding-criteria '{"Criterion":{"severity":{"Gte":7}}}'

# 2. Check Security Hub
aws securityhub get-findings \
  --filters '{"SeverityLabel":[{"Value":"CRITICAL","Comparison":"EQUALS"}]}'

# 3. Isolate compromised pod (NetworkPolicy)
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: quarantine-pod
  namespace: retail-apps
spec:
  podSelector:
    matchLabels:
      app: <COMPROMISED_SERVICE>
  policyTypes:
    - Ingress
    - Egress
EOF

# 4. Capture forensic data
kubectl logs deployment/<service> -n retail-apps --since=1h > /tmp/forensic-logs.txt
kubectl describe pod <pod-name> -n retail-apps > /tmp/forensic-describe.txt
```

---

## Troubleshooting

### Pod CrashLoopBackOff
```bash
kubectl describe pod <pod> -n <ns>         # Check events
kubectl logs <pod> -n <ns> --previous      # Previous container logs
kubectl get events -n <ns> --sort-by='.lastTimestamp'
```

### ImagePullBackOff
```bash
# Check ECR login
aws ecr get-login-password | docker login --username AWS --password-stdin <registry>

# Verify image exists
aws ecr describe-images --repository-name eks-retail/<service> --image-ids imageTag=<tag>

# Check node can reach ECR (VPC endpoint)
kubectl run test --rm -it --image=busybox -- wget -qO- https://ecr.us-east-1.amazonaws.com/
```

### Istio Issues
```bash
# Check sidecar injection
kubectl get namespace <ns> --show-labels | grep istio-injection

# Analyze Istio config
istioctl analyze -n retail-apps
istioctl proxy-status

# Check envoy config
istioctl proxy-config routes <pod-name> -n retail-apps
istioctl proxy-config clusters <pod-name> -n retail-apps
```

### Database Connectivity
```bash
# Test from pod
kubectl exec -it deployment/storefront-api -n retail-apps -- \
  python -c "
import asyncio, asyncpg
async def test():
    conn = await asyncpg.connect('postgresql://...')
    print(await conn.fetchval('SELECT 1'))
asyncio.run(test())
"

# Check Aurora status
aws rds describe-db-clusters --db-cluster-identifier eks-retail-prod-aurora
```

---

## Maintenance Procedures

### EKS Version Upgrade
```bash
# 1. Update Terraform
# Change kubernetes_version in terraform.tfvars

# 2. Plan and apply
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars

# 3. Update system node group (automatic with Terraform)
# 4. Karpenter nodes auto-update via drift detection

# 5. Verify
kubectl get nodes -o wide
kubectl version --short
```

### Karpenter Upgrade
```bash
helm upgrade karpenter oci://public.ecr.aws/karpenter/karpenter \
  --namespace kube-system --version <NEW_VERSION> --reuse-values
```

### Certificate Rotation
```bash
# Istio mTLS certs (auto-rotated)
istioctl proxy-config secret <pod-name> -n retail-apps

# ALB/Gateway TLS cert
aws acm describe-certificate --certificate-arn <ARN>
```

### Secret Rotation
```bash
# Aurora credentials (auto-rotation via Secrets Manager)
aws secretsmanager describe-secret --secret-id eks-retail-prod/aurora/credentials

# Force rotation
aws secretsmanager rotate-secret --secret-id eks-retail-prod/aurora/credentials
```

---

## Disaster Recovery

### RTO/RPO Targets
| Component | RTO | RPO | Strategy |
|---|---|---|---|
| EKS Cluster | 30 min | N/A | Terraform re-apply |
| Aurora Database | 5 min | 1 sec | Multi-AZ failover |
| Application | 5 min | N/A | ArgoCD re-sync |
| SQS Messages | 0 | 0 | Managed service |

### Aurora Failover
```bash
# Force failover to reader
aws rds failover-db-cluster --db-cluster-identifier eks-retail-prod-aurora

# Restore from snapshot
aws rds restore-db-cluster-from-snapshot \
  --db-cluster-identifier eks-retail-prod-aurora-restored \
  --snapshot-identifier <SNAPSHOT_ID> \
  --engine aurora-postgresql
```

### Full Cluster Recreation
```bash
# 1. Ensure state is intact
terraform init -backend-config=backend.hcl

# 2. Import any drifted resources
terraform plan -var-file=terraform.tfvars

# 3. Apply
terraform apply -var-file=terraform.tfvars

# 4. ArgoCD will auto-sync all K8s resources
kubectl apply -f kubernetes/argocd/applications/app-of-apps.yaml
```

---

## DORA Metrics Monitoring

| Metric | How to Check | Elite Target |
|---|---|---|
| **Deployment Frequency** | GitHub → Environments → dev → Activity | Multiple per day |
| **Lead Time for Changes** | GitHub Actions → App Pipeline → DORA Metrics step | < 1 hour |
| **Change Failure Rate** | CloudWatch → EKSRetail/DORA namespace | < 15% |
| **MTTR** | PagerDuty/Opsgenie incident duration | < 1 hour |

```bash
# Query DORA from CloudWatch
aws cloudwatch get-metric-statistics \
  --namespace "EKSRetail/DORA" \
  --metric-name "LeadTimeSeconds" \
  --start-time $(date -d '7 days ago' -u +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 86400 \
  --statistics Average
```
