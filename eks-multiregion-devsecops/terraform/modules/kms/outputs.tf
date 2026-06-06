# ==============================================================================
# KMS Module — Outputs
# ==============================================================================

output "eks_key_arn" {
  description = "ARN of the KMS key for EKS secrets encryption"
  value       = aws_kms_key.eks.arn
}

output "eks_key_id" {
  description = "ID of the KMS key for EKS secrets encryption"
  value       = aws_kms_key.eks.key_id
}

output "ebs_key_arn" {
  description = "ARN of the KMS key for EBS volume encryption"
  value       = aws_kms_key.ebs.arn
}

output "ebs_key_id" {
  description = "ID of the KMS key for EBS volume encryption"
  value       = aws_kms_key.ebs.key_id
}

output "rds_key_arn" {
  description = "ARN of the KMS key for Aurora/RDS encryption"
  value       = aws_kms_key.rds.arn
}

output "rds_key_id" {
  description = "ID of the KMS key for Aurora/RDS encryption"
  value       = aws_kms_key.rds.key_id
}

output "s3_key_arn" {
  description = "ARN of the KMS key for S3 bucket encryption"
  value       = aws_kms_key.s3.arn
}

output "s3_key_id" {
  description = "ID of the KMS key for S3 bucket encryption"
  value       = aws_kms_key.s3.key_id
}

output "sns_key_arn" {
  description = "ARN of the KMS key for SNS encryption"
  value       = aws_kms_key.sns.arn
}

output "sns_key_id" {
  description = "ID of the KMS key for SNS encryption"
  value       = aws_kms_key.sns.key_id
}

output "sqs_key_arn" {
  description = "ARN of the KMS key for SQS encryption"
  value       = aws_kms_key.sqs.arn
}

output "sqs_key_id" {
  description = "ID of the KMS key for SQS encryption"
  value       = aws_kms_key.sqs.key_id
}
