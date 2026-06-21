# ─────────────────────────────────────────────────────────────────────────────
# Security Module — Outputs
# ─────────────────────────────────────────────────────────────────────────────

output "kms_key_arn" {
  description = "General purpose KMS key ARN"
  value       = aws_kms_key.general.arn
}

output "kms_key_id" {
  description = "General purpose KMS key ID"
  value       = aws_kms_key.general.key_id
}

output "cloudtrail_arn" {
  description = "CloudTrail ARN"
  value       = aws_cloudtrail.main.arn
}

output "waf_acl_arn" {
  description = "WAF Web ACL ARN (for ALB association)"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].arn : ""
}

output "ecr_repository_urls" {
  description = "ECR repository URLs"
  value       = { for k, v in aws_ecr_repository.services : k => v.repository_url }
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = var.enable_guardduty ? aws_guardduty_detector.main[0].id : ""
}
