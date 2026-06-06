# =============================================================================
# Outputs
# Project: 3-Tier EKS Application
# Author: Pushparaj Naik
# =============================================================================

# --- EKS ---
output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint URL"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_certificate_authority" {
  description = "EKS cluster certificate authority data"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

# --- Network ---
output "vpc_id" {
  description = "VPC ID"
  value       = module.eks_network.vpc_id
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = module.eks_network.private_subnets
}

# --- RDS ---
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.rds.endpoint
  sensitive   = true
}

output "rds_db_name" {
  description = "RDS database name"
  value       = module.rds.db_name
}

output "db_secret_arn" {
  description = "Secrets Manager ARN for database connection string"
  value       = module.rds.secret_arn
  sensitive   = true
}

# --- OIDC ---
output "github_oidc_role_arn" {
  description = "IAM Role ARN for GitHub Actions OIDC"
  value       = module.github_oidc.role_arn
}

# --- General ---
output "account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

# --- Compliance ---
output "cloudtrail_log_group" {
  description = "CloudTrail CloudWatch log group name"
  value       = module.compliance.cloudtrail_log_group
}

# --- GitOps / ArgoCD ---
output "argocd_server_url" {
  description = "ArgoCD server URL (port-forward to access)"
  value       = module.argocd.server_url_command
}

output "argocd_initial_admin_password" {
  description = "Command to retrieve ArgoCD initial admin password"
  value       = module.argocd.admin_password_command
}

# --- State Management ---
output "terraform_state_bucket" {
  description = "S3 bucket for Terraform remote state"
  value       = module.state.bucket_id
}

output "terraform_lock_table" {
  description = "DynamoDB table for Terraform state locking"
  value       = module.state.dynamodb_table_id
}
