# =============================================================================
# AWS Storage Module — Outputs
# =============================================================================

output "bronze_bucket_arn" {
  description = "ARN of the Bronze landing S3 bucket"
  value       = aws_s3_bucket.medallion["bronze"].arn
}

output "bronze_bucket_name" {
  description = "Name of the Bronze landing S3 bucket"
  value       = aws_s3_bucket.medallion["bronze"].id
}

output "silver_bucket_arn" {
  description = "ARN of the Silver curated S3 bucket"
  value       = aws_s3_bucket.medallion["silver"].arn
}

output "silver_bucket_name" {
  description = "Name of the Silver curated S3 bucket"
  value       = aws_s3_bucket.medallion["silver"].id
}

output "gold_bucket_arn" {
  description = "ARN of the Gold aggregated S3 bucket"
  value       = aws_s3_bucket.medallion["gold"].arn
}

output "gold_bucket_name" {
  description = "Name of the Gold aggregated S3 bucket"
  value       = aws_s3_bucket.medallion["gold"].id
}

output "audit_log_bucket_arn" {
  description = "ARN of the immutable audit log S3 bucket"
  value       = aws_s3_bucket.audit_logs.arn
}

output "audit_log_bucket_name" {
  description = "Name of the immutable audit log S3 bucket"
  value       = aws_s3_bucket.audit_logs.id
}

output "medallion_bucket_arns" {
  description = "Map of medallion tier to bucket ARN"
  value = {
    for k, v in aws_s3_bucket.medallion : k => v.arn
  }
}
