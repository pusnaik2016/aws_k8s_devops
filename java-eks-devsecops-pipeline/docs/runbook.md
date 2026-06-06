# 📋 Operations Runbook — DevSecOps Pipeline

> Comprehensive operational guide for deploying, managing, and troubleshooting the production DevSecOps pipeline on AWS.

---

## Table of Contents

1. [Pre-Deployment Checklist](#1-pre-deployment-checklist)
2. [Initial Infrastructure Deployment](#2-initial-infrastructure-deployment)
3. [GitHub Actions Configuration](#3-github-actions-configuration)
4. [SonarCloud Setup](#4-sonarcloud-setup)
5. [Bastion & EKS kubectl Setup](#5-bastion--eks-kubectl-setup)
6. [ArgoCD Setup](#6-argocd-setup)
7. [Cognito User Management](#7-cognito-user-management)
8. [DNS & Certificate Setup](#8-dns--certificate-setup)
9. [Day-2 Operations](#9-day-2-operations)
10. [Monitoring & Logging](#10-monitoring--logging)
11. [Scaling Procedures](#11-scaling-procedures)
12. [Disaster Recovery](#12-disaster-recovery)
13. [Troubleshooting Guide](#13-troubleshooting-guide)
14. [Cost Management](#14-cost-management)
15. [Security Incident Response](#15-security-incident-response)
16. [Teardown Procedure](#16-teardown-procedure)

---

## 1. Pre-Deployment Checklist

### AWS Account Requirements

| Requirement | How to Verify | Notes |
|:------------|:-------------|:------|
| AWS Account with admin access | `aws sts get-caller-identity` | Record the Account ID |
| EC2 Key Pair created | AWS Console → EC2 → Key Pairs | Download `.pem` file |
| Service quotas sufficient | AWS Console → Service Quotas | EKS, VPC, EIP limits |
| Domain name registered | Route53 or external registrar | Needed for Route53 + ACM |
| Terraform ≥ 1.5 installed | `terraform version` | Install from terraform.io |
| AWS CLI v2 configured | `aws configure list` | Needs valid credentials |
| Git configured | `git config --list` | Needed for repo operations |

### GitHub Requirements

| Requirement | How to Verify |
|:------------|:-------------|
| GitHub repository created | github.com/your-org/Java_DevSecOps |
| GitHub PAT with `repo` scope | Settings → Developer Settings → PAT |
| SonarCloud account | [sonarcloud.io](https://sonarcloud.io) |
| SonarCloud organization created | sonarcloud.io → Organizations |

### Pre-Flight Validation

```bash
# Verify AWS access
aws sts get-caller-identity

# Verify region
aws configure get region

# Verify Terraform
terraform version

# Verify key pair exists
aws ec2 describe-key-pairs --key-names devsecops-key

# Check EKS service quota (need at least 1 cluster)
aws service-quotas get-service-quota \
  --service-code eks \
  --quota-code L-1194D53C
```

---

## 2. Initial Infrastructure Deployment

### Step 2.1: Configure Variables

```bash
cd terraform/
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
aws_region            = "us-east-1"
project_name          = "java-devsecops"
key_pair_name         = "devsecops-key"
allowed_ssh_cidr      = "YOUR_PUBLIC_IP/32"     # Lock down SSH access!
github_org            = "your-github-username"
github_repo           = "Java_DevSecOps"
domain_name           = "yourdomain.com"
create_route53_zone   = true
single_nat_gateway    = true                     # false for HA ($96/mo)
eks_node_desired_size = 2
```

### Step 2.2: Initialize and Plan

```bash
# Initialize providers and modules
terraform init

# Preview all resources that will be created
terraform plan -out=tfplan

# Review the plan carefully — expect ~60+ resources
```

### Step 2.3: Apply Infrastructure

```bash
# Apply the plan (takes ~15-25 minutes)
terraform apply tfplan

# Save outputs for later reference
terraform output > terraform-outputs.txt
terraform output -json > terraform-outputs.json
```

### Step 2.4: Expected Resource Creation Order

```
1. VPC + Subnets + IGW + Route Tables              (~1 min)
2. Security Groups                                   (~30 sec)
3. VPC Endpoints (6 PrivateLink endpoints)           (~3 min)
4. NAT Gateway + Elastic IP                          (~2 min)
5. KMS Key for EKS secrets                           (~30 sec)
6. IAM Roles (cluster, nodes, ALB controller, OIDC)  (~1 min)
7. EKS Cluster                                       (~10-12 min) ← longest
8. EKS Node Group                                    (~5-7 min)
9. EKS Add-ons (vpc-cni, coredns, kube-proxy)       (~2 min)
10. Helm: ALB Controller + ArgoCD                    (~3 min)
11. ALB + Target Group + Listeners                   (~2 min)
12. WAF Web ACL + Association                         (~1 min)
13. API Gateway + VPC Link + Authorizer              (~1 min)
14. Route53 Zone + ACM Certificate + DNS Records     (~2 min)
15. Cognito User Pool + Client + Domain              (~1 min)
16. ECR Repository + Lifecycle Policy                (~30 sec)
17. GitHub OIDC Provider + IAM Role                  (~30 sec)
18. Bastion EC2                                       (~2 min)
```

### Step 2.5: Post-Apply Verification

```bash
# Verify all outputs
terraform output

# Key outputs to note:
terraform output bastion_public_ip
terraform output eks_cluster_name
terraform output ecr_repository_url
terraform output github_actions_role_arn
terraform output cognito_hosted_ui_url
terraform output route53_nameservers
```

---

## 3. GitHub Actions Configuration

### Step 3.1: Add GitHub Secrets

Navigate to: **GitHub Repo → Settings → Secrets and variables → Actions → New repository secret**

| Secret Name | Value | Source |
|:------------|:------|:-------|
| `AWS_ACCOUNT_ID` | `123456789012` | `aws sts get-caller-identity --query Account --output text` |
| `SONAR_TOKEN` | `sqa_xxx...` | SonarCloud → My Account → Security → Generate Token |
| `SONAR_ORGANIZATION` | `your-org-key` | SonarCloud → Organization Settings |
| `MANIFEST_REPO_TOKEN` | `ghp_xxx...` | GitHub → Settings → Developer Settings → PAT (repo scope) |

### Step 3.2: Add GitHub Variables

Navigate to: **GitHub Repo → Settings → Secrets and variables → Actions → Variables → New repository variable**

| Variable Name | Value |
|:-------------|:------|
| `AWS_REGION` | `us-east-1` |
| `SONAR_PROJECT_KEY` | `boardgame-app` |
| `MANIFEST_REPO` | `your-org/boardgame-k8s-manifests` |

### Step 3.3: Verify OIDC Role ARN

The CI workflow references the role as:
```
arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/github-actions-ecr-role
```

Verify it exists:
```bash
terraform output github_actions_role_arn
aws iam get-role --role-name java-devsecops-github-actions-ecr-role
```

### Step 3.4: Test CI Pipeline

```bash
# Make a small change and push
echo "# test" >> README.md
git add . && git commit -m "test: trigger CI pipeline"
git push origin main
```

Monitor: **GitHub Repo → Actions tab → CI Pipeline workflow**

Expected: All 12 stages pass, image pushed to ECR.

---

## 4. SonarCloud Setup

### Step 4.1: Create Organization

1. Go to [sonarcloud.io](https://sonarcloud.io)
2. Log in with GitHub
3. **Import organization** → Select your GitHub org
4. Note the **Organization Key** → use as `SONAR_ORGANIZATION` secret

### Step 4.2: Create Project

1. **Analyze new project** → Select `Java_DevSecOps` repo
2. Set **Project Key** to `boardgame-app`
3. Choose **GitHub Actions** as CI
4. Copy the **SONAR_TOKEN** → add as GitHub Secret

### Step 4.3: Configure Quality Gate

1. Navigate to project → **Quality Gate** tab
2. Use **Sonar way** (default) or create custom:
   - Coverage ≥ 80%
   - Duplicated Lines ≤ 3%
   - Maintainability Rating = A
   - Reliability Rating = A
   - Security Rating = A

---

## 5. Bastion & EKS kubectl Setup

### Step 5.1: SSH into Bastion

```bash
# Get bastion IP
BASTION_IP=$(terraform output -raw bastion_public_ip)

# SSH in
ssh -i ~/.ssh/devsecops-key.pem ubuntu@${BASTION_IP}
```

### Step 5.2: Configure AWS Credentials on Bastion

```bash
# Option A: Configure with access keys
aws configure
# Enter: Access Key, Secret Key, Region (us-east-1), Format (json)

# Option B: Attach IAM Instance Profile (recommended)
# This is done via Terraform — add an instance profile to ec2-bastion.tf
```

### Step 5.3: Configure kubectl

```bash
# Update kubeconfig for the private EKS cluster
aws eks update-kubeconfig --region us-east-1 --name java-devsecops-eks

# Verify connection
kubectl cluster-info
kubectl get nodes

# Expected output:
# NAME                                     STATUS   ROLES    AGE   VERSION
# ip-10-0-101-xxx.ec2.internal            Ready    <none>   10m   v1.29.x
# ip-10-0-102-xxx.ec2.internal            Ready    <none>   10m   v1.29.x
```

### Step 5.4: Verify EKS Add-ons

```bash
# Check ALB Controller
kubectl get pods -n kube-system | grep aws-load-balancer

# Check ArgoCD
kubectl get pods -n argocd

# Check CoreDNS
kubectl get pods -n kube-system | grep coredns

# Check all namespaces
kubectl get ns
```

---

## 6. ArgoCD Setup

### Step 6.1: Deploy ArgoCD Application CR

```bash
# From the bastion host
kubectl apply -f argocd/application.yaml

# Verify the Application CR was created
kubectl get applications -n argocd
```

### Step 6.2: Get ArgoCD Admin Password

```bash
# The initial admin password is stored in a Kubernetes secret
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Save this password — you'll need it for the ArgoCD UI
```

### Step 6.3: Access ArgoCD UI

ArgoCD is exposed via the ALB (configured in eks-addons.tf). Access it at:
```
https://app.yourdomain.com/argocd
```

Or port-forward from the bastion:
```bash
kubectl port-forward svc/argocd-server -n argocd 8443:443 --address 0.0.0.0 &
# Access: https://<BASTION_IP>:8443
```

Login: `admin` / `<password from step 6.2>`

### Step 6.4: Verify Sync Status

```bash
# Check ArgoCD application status
kubectl get applications -n argocd -o wide

# Expected output:
# NAME            SYNC STATUS   HEALTH STATUS   
# boardgame-app   Synced        Healthy
```

---

## 7. Cognito User Management

### Step 7.1: Create Test User

```bash
# Create a user in Cognito
aws cognito-idp admin-create-user \
  --user-pool-id $(terraform output -raw cognito_user_pool_id) \
  --username "testuser@example.com" \
  --user-attributes Name=email,Value=testuser@example.com Name=name,Value="Test User" \
  --temporary-password "TempPass123!"

# Set permanent password (skip force change)
aws cognito-idp admin-set-user-password \
  --user-pool-id $(terraform output -raw cognito_user_pool_id) \
  --username "testuser@example.com" \
  --password "SecurePass123!" \
  --permanent
```

### Step 7.2: Get JWT Token

```bash
CLIENT_ID=$(terraform output -raw cognito_client_id)
USER_POOL_ID=$(terraform output -raw cognito_user_pool_id)

# Initiate auth
aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id ${CLIENT_ID} \
  --auth-parameters USERNAME=testuser@example.com,PASSWORD=SecurePass123!

# Response contains: AccessToken, IdToken, RefreshToken
```

### Step 7.3: Test Authenticated API Call

```bash
TOKEN="<AccessToken from step 7.2>"

# Test API Gateway with JWT
curl -H "Authorization: Bearer ${TOKEN}" \
  https://api.yourdomain.com/api/health

# Expected: 200 OK with health status

# Test without token (should fail)
curl https://api.yourdomain.com/api/health
# Expected: 401 Unauthorized
```

---

## 8. DNS & Certificate Setup

### Step 8.1: Update Domain Nameservers

```bash
# Get Route53 nameservers
terraform output route53_nameservers
```

Go to your domain registrar and update the nameservers to the 4 Route53 NS records.

### Step 8.2: Verify DNS Propagation

```bash
# Check if DNS is resolving (may take 24-48 hours for full propagation)
dig app.yourdomain.com
dig api.yourdomain.com

# Verify ACM certificate status
aws acm list-certificates --region us-east-1
```

### Step 8.3: Verify HTTPS

```bash
# Test HTTPS endpoint
curl -I https://app.yourdomain.com
# Expected: HTTP/2 200 (or 301/302 if app redirects)

# Check certificate details
echo | openssl s_client -connect app.yourdomain.com:443 -servername app.yourdomain.com 2>/dev/null | openssl x509 -noout -subject -dates
```

---

## 9. Day-2 Operations

### 9.1 Application Deployment (Normal Flow)

```bash
# Developer workflow — just push code
git add . && git commit -m "feat: add new feature"
git push origin main

# Automated flow:
# 1. GitHub Actions CI runs (build, test, scan, push to ECR)     ~5-8 min
# 2. GitHub Actions CD runs (update manifest repo)               ~1 min  
# 3. ArgoCD detects change and syncs                             ~3 min
# Total: ~9-12 minutes from push to production
```

### 9.2 Manual Rollback

```bash
# From bastion — rollback to previous image
kubectl -n boardgame rollout undo deployment/boardgame-app

# Or rollback to specific revision
kubectl -n boardgame rollout undo deployment/boardgame-app --to-revision=3

# Check rollout status
kubectl -n boardgame rollout status deployment/boardgame-app
```

### 9.3 ArgoCD Rollback (via Git)

```bash
# Revert the manifest change in Git
cd boardgame-k8s-manifests/
git log --oneline -5
git revert HEAD
git push origin main
# ArgoCD will automatically sync the reverted state
```

### 9.4 EKS Node Group Update

```bash
# Update node AMI (in terraform.tfvars)
# Change eks_cluster_version or force new launch template

terraform plan
terraform apply

# The node group performs a rolling update automatically
# Watch with: kubectl get nodes -w
```

### 9.5 Scaling EKS Nodes

```bash
# Quick scale via AWS CLI
aws eks update-nodegroup-config \
  --cluster-name java-devsecops-eks \
  --nodegroup-name java-devsecops-node-group \
  --scaling-config minSize=2,desiredSize=3,maxSize=6

# Or update terraform.tfvars and apply
```

---

## 10. Monitoring & Logging

### 10.1 EKS Control Plane Logs

```bash
# View logs in CloudWatch (Log Group: /aws/eks/java-devsecops-eks/cluster)
aws logs describe-log-groups --log-group-name-prefix "/aws/eks/java-devsecops"

# Tail API server logs
aws logs tail "/aws/eks/java-devsecops-eks/cluster" --follow --filter-pattern "ERROR"
```

### 10.2 Application Logs

```bash
# From bastion
kubectl logs -n boardgame -l app=boardgame-app --tail=100 -f

# Logs from specific pod
kubectl logs -n boardgame <pod-name> --tail=50
```

### 10.3 WAF Metrics

```bash
# View WAF blocked requests
aws wafv2 get-sampled-requests \
  --web-acl-arn $(terraform output -raw waf_web_acl_arn) \
  --rule-metric-name java-devsecops-rate-limit \
  --scope REGIONAL \
  --time-window StartTime=2024-01-01T00:00:00Z,EndTime=2024-12-31T23:59:59Z \
  --max-items 10
```

### 10.4 API Gateway Logs

```bash
# View API Gateway access logs
aws logs tail "/aws/apigateway/java-devsecops-api" --follow
```

### 10.5 ALB Health Checks

```bash
# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --names java-devsecops-app-tg \
    --query 'TargetGroups[0].TargetGroupArn' --output text)
```

---

## 11. Scaling Procedures

### 11.1 Horizontal Pod Scaling

```bash
# Scale application pods (from bastion)
kubectl -n boardgame scale deployment/boardgame-app --replicas=4

# Or add HPA (Horizontal Pod Autoscaler)
kubectl -n boardgame autoscale deployment/boardgame-app \
  --cpu-percent=70 --min=2 --max=8
```

### 11.2 EKS Node Scaling

```bash
# Update in terraform.tfvars
eks_node_min_size     = 2
eks_node_desired_size = 4
eks_node_max_size     = 8

# Apply changes
terraform apply
```

### 11.3 NAT Gateway HA Scaling

```bash
# For production HA — switch from 1 to 3 NAT Gateways
# In terraform.tfvars:
single_nat_gateway = false

terraform apply
# Cost: +$64/month
```

---

## 12. Disaster Recovery

### 12.1 EKS Cluster Recovery

The EKS control plane is fully managed by AWS across 3 AZs. If a node fails:
1. The managed node group auto-replaces it
2. Pods on the failed node are rescheduled to healthy nodes
3. `topologySpreadConstraints` ensure pods are distributed across AZs

### 12.2 Full Infrastructure Recovery

```bash
# Infrastructure is fully defined in Terraform
# To rebuild from scratch:
terraform init
terraform apply

# Application state is in Git (GitOps) — ArgoCD will auto-sync
# Container images are in ECR (persisted)
```

### 12.3 Backup EKS Resources

```bash
# From bastion — export all resources
kubectl get all -n boardgame -o yaml > boardgame-backup.yaml
kubectl get all -n argocd -o yaml > argocd-backup.yaml
```

### 12.4 ECR Image Recovery

```bash
# ECR lifecycle keeps last 10 tagged images
# To list available images for rollback:
aws ecr describe-images \
  --repository-name java-devsecops/boardgame-app \
  --query 'sort_by(imageDetails,& imagePushedAt)[-10:].imageTags' \
  --output table
```

---

## 13. Troubleshooting Guide

### 13.1 GitHub Actions CI Fails

| Issue | Diagnosis | Resolution |
|:------|:----------|:-----------|
| OIDC auth fails | Check IAM role trust policy | Verify `github_org` and `github_repo` in tfvars match exactly |
| ECR push denied | Check IAM policy | Run `aws iam get-role-policy --role-name java-devsecops-github-actions-ecr-role --policy-name java-devsecops-github-actions-ecr-policy` |
| SonarCloud fails | Check token | Regenerate SONAR_TOKEN in SonarCloud and update GitHub Secret |
| Trivy scan timeout | Rate limit | Add `--timeout 10m` to Trivy action |

### 13.2 EKS Issues

| Issue | Diagnosis | Resolution |
|:------|:----------|:-----------|
| `kubectl` connection refused | Private endpoint | Ensure you're on bastion (within VPC) |
| Nodes not joining | Check node IAM role | `aws eks describe-nodegroup` + check CloudWatch logs |
| Pods stuck `Pending` | Resource constraints | `kubectl describe pod <pod>` → check Events |
| Pods in `CrashLoopBackOff` | Application error | `kubectl logs <pod> -n boardgame --previous` |
| ImagePullBackOff | ECR auth or VPC endpoint | Check VPC endpoints: `aws ec2 describe-vpc-endpoints` |

### 13.3 ALB Issues

| Issue | Diagnosis | Resolution |
|:------|:----------|:-----------|
| 502 Bad Gateway | No healthy targets | Check target group health (section 10.5) |
| 503 Service Unavailable | No registered targets | Verify ALB Controller pods are running |
| Certificate error | ACM not validated | Check `aws acm describe-certificate` for validation status |

### 13.4 ArgoCD Issues

```bash
# Check ArgoCD application status
kubectl get applications -n argocd -o yaml

# Check sync errors
kubectl -n argocd logs -l app.kubernetes.io/name=argocd-application-controller

# Force sync
kubectl -n argocd patch application boardgame-app \
  -p '{"operation": {"sync": {}}}' --type merge
```

### 13.5 WAF Blocking Legitimate Traffic

```bash
# Check sampled requests
aws wafv2 get-sampled-requests \
  --web-acl-arn $(terraform output -raw waf_web_acl_arn) \
  --rule-metric-name java-devsecops-rate-limit \
  --scope REGIONAL \
  --time-window StartTime=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ),EndTime=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --max-items 20

# Temporarily increase rate limit
# In terraform.tfvars: waf_rate_limit = 5000
# terraform apply
```

### 13.6 Cognito Auth Issues

```bash
# Check user status
aws cognito-idp admin-get-user \
  --user-pool-id $(terraform output -raw cognito_user_pool_id) \
  --username "user@example.com"

# Reset user password
aws cognito-idp admin-set-user-password \
  --user-pool-id $(terraform output -raw cognito_user_pool_id) \
  --username "user@example.com" \
  --password "NewSecurePass123!" \
  --permanent
```

---

## 14. Cost Management

### Monthly Cost Breakdown

| Resource | Cost | Optimization |
|:---------|:-----|:-------------|
| EKS Control Plane | ~$73 | Fixed cost |
| EKS Nodes (2× t3.medium) | ~$60 | Use Spot for non-prod |
| NAT Gateway (1 shared) | ~$32 | Required for private subnets |
| ALB | ~$16 | Fixed cost |
| VPC Endpoints (5) | ~$36 | Required for private EKS |
| Bastion (t3.micro) | ~$8 | **Stop when not in use** |
| WAF + API GW + ECR | ~$10 | Usage-based |
| GitHub Actions | **Free** | 2000 min/mo |
| SonarCloud | **Free** | Public repos |
| **Total** | **~$235/mo** | |

### Cost Optimization Tips

```bash
# Stop bastion when not in use (saves ~$8/mo)
aws ec2 stop-instances --instance-ids $(terraform output -raw bastion_instance_id)

# Start when needed
aws ec2 start-instances --instance-ids $(terraform output -raw bastion_instance_id)

# Use Spot instances for non-prod EKS nodes (saves ~40%)
# In eks.tf: capacity_type = "SPOT"

# Use single NAT gateway for dev (saves $64/mo vs 3 NAT GWs)
# Already configured: single_nat_gateway = true
```

---

## 15. Security Incident Response

### 15.1 Suspected Breach — Immediate Actions

```bash
# 1. Block all traffic via WAF (emergency rule)
aws wafv2 update-web-acl \
  --name java-devsecops-waf \
  --scope REGIONAL \
  --default-action Block={} \
  --id <WEB_ACL_ID> \
  --lock-token <LOCK_TOKEN>

# 2. Rotate Cognito user pool passwords
# Force password reset for all users

# 3. Check WAF logs for attack patterns
aws logs tail "/aws/waf/java-devsecops" --follow

# 4. Check API Gateway access logs
aws logs tail "/aws/apigateway/java-devsecops-api" --follow

# 5. Isolate suspicious pods
kubectl -n boardgame cordon <node-name>
```

### 15.2 Credential Rotation

```bash
# Rotate GitHub OIDC — thumbprints auto-rotate
# Rotate Cognito client — create new client in Terraform, update apps

# Rotate KMS key
aws kms create-key --description "New EKS encryption key"
# Update eks.tf with new key ARN, terraform apply

# Rotate ECR — no credentials to rotate (OIDC + IAM role)
```

---

## 16. Teardown Procedure

### Step 16.1: Remove ArgoCD Application

```bash
# From bastion — remove ArgoCD app first to clean up K8s resources
kubectl delete application boardgame-app -n argocd
# Wait for resources to be pruned
kubectl get all -n boardgame
```

### Step 16.2: Destroy Infrastructure

```bash
cd terraform/

# Preview destruction
terraform plan -destroy

# Destroy all resources (~10-15 minutes)
terraform destroy

# Confirm with 'yes' when prompted
```

### Step 16.3: Post-Teardown Cleanup

```bash
# Remove kubeconfig entry
kubectl config delete-context <context-name>

# Remove GitHub Secrets (optional)
# GitHub Repo → Settings → Secrets → Delete each secret

# Remove SonarCloud project (optional)
# sonarcloud.io → Project Settings → Delete
```

### Expected Teardown Order

```
1. Helm releases (ArgoCD, ALB Controller)
2. EKS Add-ons (vpc-cni, coredns, kube-proxy)
3. EKS Node Group
4. EKS Cluster
5. ALB + Target Group + Listeners
6. WAF Web ACL
7. API Gateway + VPC Link
8. Route53 Records + ACM Certificate
9. Cognito User Pool
10. ECR Repository
11. NAT Gateway + EIP
12. VPC Endpoints
13. Security Groups
14. Subnets + Route Tables
15. VPC + IGW
16. IAM Roles + Policies
17. KMS Key
18. Bastion EC2
```

---

## Appendix A: Important Commands Cheat Sheet

```bash
# === Bastion Access ===
ssh -i ~/.ssh/devsecops-key.pem ubuntu@$(terraform output -raw bastion_public_ip)

# === kubectl ===
aws eks update-kubeconfig --region us-east-1 --name java-devsecops-eks
kubectl get nodes
kubectl get pods -n boardgame
kubectl logs -n boardgame -l app=boardgame-app -f
kubectl describe pod <pod-name> -n boardgame
kubectl rollout restart deployment/boardgame-app -n boardgame

# === ArgoCD ===
kubectl get applications -n argocd
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# === ECR ===
aws ecr describe-images --repository-name java-devsecops/boardgame-app --query 'imageDetails[*].imageTags'

# === WAF ===
aws wafv2 get-web-acl --name java-devsecops-waf --scope REGIONAL --id <ACL_ID>

# === Cognito ===
aws cognito-idp list-users --user-pool-id $(terraform output -raw cognito_user_pool_id)

# === Cost ===
aws ce get-cost-and-usage --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY --metrics BlendedCost \
  --filter '{"Tags":{"Key":"Project","Values":["java-devsecops"]}}'
```

---

## Appendix B: Emergency Contacts / Escalation

| Issue | First Responder | Escalation |
|:------|:---------------|:-----------|
| Pipeline failure | DevOps team | GitHub Actions → Actions tab |
| Security incident | Security team | AWS WAF logs + CloudTrail |
| EKS outage | DevOps + AWS | AWS Support Case |
| DNS issues | DevOps team | Route53 health checks |
| Cognito auth failure | Dev team | Cognito User Pool console |
