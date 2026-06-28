# =============================================================================
# AWS Security Module — Outputs
# =============================================================================

# KMS Key ARNs
output "s3_data_kms_key_arn" {
  description = "ARN of the KMS key for S3 medallion data"
  value       = aws_kms_key.s3_data.arn
}

output "s3_data_kms_key_id" {
  description = "ID of the KMS key for S3 medallion data"
  value       = aws_kms_key.s3_data.key_id
}

output "databricks_kms_key_arn" {
  description = "ARN of the KMS key for Databricks managed services"
  value       = aws_kms_key.databricks.arn
}

output "logs_kms_key_arn" {
  description = "ARN of the KMS key for CloudWatch/CloudTrail logs"
  value       = aws_kms_key.logs.arn
}

# Secrets Manager ARNs
output "databricks_token_secret_arn" {
  description = "ARN of the Databricks PAT secret"
  value       = aws_secretsmanager_secret.databricks_token.arn
}

output "warehouse_credentials_secret_arn" {
  description = "ARN of the warehouse credentials secret"
  value       = aws_secretsmanager_secret.warehouse_credentials.arn
}

output "tokenization_key_secret_arn" {
  description = "ARN of the PII tokenization key secret"
  value       = aws_secretsmanager_secret.tokenization_key.arn
}

# IAM Role ARNs
output "databricks_cross_account_role_arn" {
  description = "ARN of the Databricks cross-account IAM role"
  value       = aws_iam_role.databricks_cross_account.arn
}

output "github_deployer_role_arn" {
  description = "ARN of the GitHub Actions OIDC deployer role"
  value       = aws_iam_role.github_deployer.arn
}

# CloudTrail
output "cloudtrail_arn" {
  description = "ARN of the CloudTrail audit trail"
  value       = aws_cloudtrail.audit.arn
}
