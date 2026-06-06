# ─────────────────────────────────────────────────────────────
# Security Module — Outputs
# ─────────────────────────────────────────────────────────────

output "eks_cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = aws_iam_role.eks_cluster.arn
}

output "eks_node_group_role_arn" {
  description = "ARN of the EKS node group IAM role"
  value       = aws_iam_role.eks_node_group.arn
}

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions deploy role"
  value       = aws_iam_role.github_actions_deploy.arn
}

output "kms_eks_key_arn" {
  description = "ARN of the KMS key for EKS secrets"
  value       = aws_kms_key.eks_secrets.arn
}

output "kms_aurora_key_arn" {
  description = "ARN of the KMS key for Aurora"
  value       = aws_kms_key.aurora.arn
}

output "kms_s3_key_arn" {
  description = "ARN of the KMS key for S3"
  value       = aws_kms_key.s3.arn
}

output "alb_security_group_id" {
  description = "Security group ID for ALB"
  value       = aws_security_group.alb.id
}

output "eks_nodes_security_group_id" {
  description = "Security group ID for EKS nodes"
  value       = aws_security_group.eks_nodes.id
}

output "aurora_security_group_id" {
  description = "Security group ID for Aurora"
  value       = aws_security_group.aurora.id
}

output "redis_security_group_id" {
  description = "Security group ID for Redis"
  value       = aws_security_group.redis.id
}

output "aurora_password_ssm_arn" {
  description = "ARN of the Aurora password SSM parameter"
  value       = aws_ssm_parameter.aurora_password.arn
}

output "redis_auth_token_ssm_arn" {
  description = "ARN of the Redis auth token SSM parameter"
  value       = aws_ssm_parameter.redis_auth_token.arn
}
