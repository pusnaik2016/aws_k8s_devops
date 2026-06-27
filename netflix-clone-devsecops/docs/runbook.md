# 📋 Runbook — Netflix Clone DevSecOps Operations

## Common Operations

### Access the EKS Cluster

```bash
# SSH into bastion
ssh -i ~/.ssh/devsecops-key.pem ubuntu@<BASTION_PUBLIC_IP>

# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name netflix-devsecops-eks

# Verify access
kubectl get nodes
kubectl get pods -n netflix-clone
```

### Check Application Status

```bash
# Pod status
kubectl get pods -n netflix-clone -o wide

# Pod logs
kubectl logs -n netflix-clone -l app=netflix-clone --tail=50

# Deployment rollout status
kubectl rollout status deployment/netflix-clone -n netflix-clone
```

### Manual Rollback

```bash
# View rollout history
kubectl rollout history deployment/netflix-clone -n netflix-clone

# Rollback to previous version
kubectl rollout undo deployment/netflix-clone -n netflix-clone

# Rollback to specific revision
kubectl rollout undo deployment/netflix-clone -n netflix-clone --to-revision=2
```

### Scale the Application

```bash
# Scale pods
kubectl scale deployment netflix-clone -n netflix-clone --replicas=4

# Check HPA status (if configured)
kubectl get hpa -n netflix-clone
```

---

## Monitoring Access

### Grafana

```bash
# From bastion
kubectl port-forward -n monitoring svc/grafana 3000:80

# Open in browser (via SSH tunnel)
# ssh -L 3000:localhost:3000 -i key.pem ubuntu@<BASTION_IP>
# Then open: http://localhost:3000
# Credentials: admin / DevSecOps2024!
```

### Prometheus

```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Open: http://localhost:9090
```

### ArgoCD

```bash
kubectl port-forward -n argocd svc/argocd-server 8080:443
# Open: https://localhost:8080
# Username: admin
# Password:
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

---

## Troubleshooting

### Pods Not Starting

```bash
# Check events
kubectl describe pod -n netflix-clone <POD_NAME>

# Check container image pull
kubectl get events -n netflix-clone --sort-by='.metadata.creationTimestamp'

# Check ECR authentication
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com
```

### ArgoCD Not Syncing

```bash
# Check ArgoCD app status
kubectl get applications -n argocd

# Force sync
kubectl -n argocd patch application netflix-clone --type merge -p '{"operation":{"sync":{"revision":"HEAD","prune":true}}}'

# Check ArgoCD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --tail=50
```

### ALB Not Routing Traffic

```bash
# Check ALB Controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=50

# Check Ingress status
kubectl describe ingress netflix-clone-ingress -n netflix-clone

# Verify target group health
aws elbv2 describe-target-health --target-group-arn <TARGET_GROUP_ARN>
```

### Health Check Failures

```bash
# Test health check endpoint from pod
kubectl exec -n netflix-clone <POD_NAME> -- wget -qO- http://localhost:80/healthz

# Check Nginx logs
kubectl logs -n netflix-clone <POD_NAME> --tail=100
```

---

## Infrastructure Operations

### Terraform Updates

```bash
cd terraform/
terraform plan -out=plan.out
terraform apply plan.out
```

### Destroy Infrastructure

```bash
# WARNING: This destroys all resources!
terraform destroy
```

### Cost Optimization

```bash
# Stop bastion when not in use
aws ec2 stop-instances --instance-ids <BASTION_INSTANCE_ID>

# Start bastion when needed
aws ec2 start-instances --instance-ids <BASTION_INSTANCE_ID>
```

---

## Security Incident Response

### Suspected Credential Leak

1. Rotate the exposed credential immediately
2. Check CloudTrail for unauthorized access:
   ```bash
   aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventName,AttributeValue=ConsoleLogin --max-results 10
   ```
3. Review GitHub Actions workflow logs for unexpected activity
4. Run Gitleaks scan on the repository

### WAF Blocking Legitimate Traffic

```bash
# Check WAF blocked requests
aws wafv2 get-sampled-requests --web-acl-arn <WAF_ACL_ARN> --rule-metric-name rate-limit --scope REGIONAL --time-window StartTime=<START>,EndTime=<END> --max-items 10

# Temporarily increase rate limit
# Update waf_rate_limit in terraform.tfvars and apply
```
