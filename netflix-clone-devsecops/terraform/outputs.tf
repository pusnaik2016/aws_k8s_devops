# ==============================================================================
# Terraform Outputs — Netflix Clone DevSecOps
# ==============================================================================

# --- Bastion ---
output "bastion_public_ip" {
  description = "Public IP of the bastion host for kubectl access"
  value       = aws_instance.bastion.public_ip
}

output "bastion_ssh_command" {
  description = "SSH command to connect to the bastion host"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_instance.bastion.public_ip}"
}

# --- EKS Cluster ---
output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint (PRIVATE — accessible from VPC only)"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_kubeconfig_command" {
  description = "Command to configure kubectl (run from bastion EC2)"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}

# --- ALB ---
output "alb_dns_name" {
  description = "ALB DNS name (use this if Route53 is not configured)"
  value       = aws_lb.app.dns_name
}

output "app_url" {
  description = "Application URL via Route53/ALB"
  value       = "https://app.${var.domain_name}"
}

# --- API Gateway ---
output "api_gateway_invoke_url" {
  description = "API Gateway invoke URL (requires Cognito JWT)"
  value       = aws_apigatewayv2_api.app.api_endpoint
}

# --- ECR ---
output "ecr_repository_url" {
  description = "ECR repository URL for Docker image push/pull"
  value       = aws_ecr_repository.app.repository_url
}

# --- GitHub Actions ---
output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC"
  value       = aws_iam_role.github_actions.arn
}

output "github_actions_setup" {
  description = "GitHub Secrets to configure for CI/CD"
  value       = <<-EOT
    Add these GitHub Secrets:
      AWS_ACCOUNT_ID      = (your AWS account ID)
      SONAR_TOKEN         = (SonarCloud token from sonarcloud.io)
      SONAR_ORGANIZATION  = (SonarCloud org key)
      TMDB_API_KEY        = (TMDB API key from themoviedb.org)
      MANIFEST_REPO_TOKEN = (GitHub PAT with repo write access)

    Add these GitHub Variables:
      AWS_REGION          = ${var.aws_region}
      SONAR_PROJECT_KEY   = netflix-clone
  EOT
}

# --- VPC ---
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.devsecops_vpc.id
}

# --- Route53 ---
output "route53_nameservers" {
  description = "Route53 nameservers (update your domain registrar)"
  value       = var.create_route53_zone ? aws_route53_zone.main[0].name_servers : ["Using existing zone"]
}

# --- Cognito ---
output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.app.id
}

output "cognito_hosted_ui_url" {
  description = "Cognito hosted sign-in page URL"
  value       = "https://${aws_cognito_user_pool_domain.app.domain}.auth.${var.aws_region}.amazoncognito.com/login?client_id=${aws_cognito_user_pool_client.app.id}&response_type=token&scope=openid+email+profile&redirect_uri=https://app.${var.domain_name}/callback"
}

# --- Compliance ---
output "cloudtrail_arn" {
  description = "CloudTrail ARN (PCI Req 10 / HIPAA / SOC 2 CC7)"
  value       = aws_cloudtrail.main.arn
}

output "security_alerts_topic_arn" {
  description = "SNS topic ARN for security alarms"
  value       = aws_sns_topic.security_alerts.arn
}

# --- Monitoring ---
output "monitoring_access" {
  description = "Commands to access monitoring UIs from bastion"
  value       = <<-EOT
    Grafana (from bastion):
      kubectl port-forward -n monitoring svc/grafana 3000:80
      Open: http://localhost:3000 (admin / DevSecOps2024!)

    Prometheus (from bastion):
      kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
      Open: http://localhost:9090

    ArgoCD (from bastion):
      kubectl port-forward -n argocd svc/argocd-server 8080:443
      Open: https://localhost:8080
      Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
  EOT
}

output "compliance_summary" {
  description = "Compliance controls active in this deployment"
  value       = <<-EOT
    Compliance Controls Active:
      PCI DSS Req 1  : WAF + Security Groups (network segmentation)
      PCI DSS Req 3  : KMS encryption at rest (EKS etcd, EBS, S3, SNS)
      PCI DSS Req 4  : TLS 1.3 via ACM + S3 DenyNonTLS bucket policy
      PCI DSS Req 6  : WAF OWASP rules + Trivy + SonarCloud
      PCI DSS Req 7  : IRSA least privilege + IAM policy change alarms
      PCI DSS Req 8  : Cognito MFA=ON + OIDC keyless auth
      PCI DSS Req 10 : CloudTrail multi-region + CW Logs + 7yr S3 retention
      HIPAA §164.312 : Audit logs + KMS + MFA + private EKS cluster
      SOC 2 CC6      : Root login alarm + IAM change alarm + SG change alarm
      SOC 2 CC7      : WAF block alarm + unauthorized API alarm + CW monitoring
      SOC 2 CC8      : GitOps (ArgoCD) + automated CI/CD pipeline
  EOT
}
