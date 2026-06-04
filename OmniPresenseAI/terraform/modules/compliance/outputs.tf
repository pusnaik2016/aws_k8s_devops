# ─────────────────────────────────────────────────────────────
# Compliance Module — Outputs
# ─────────────────────────────────────────────────────────────

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail trail"
  value       = aws_cloudtrail.main.arn
}

output "cloudtrail_s3_bucket" {
  description = "S3 bucket for CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail.id
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = aws_guardduty_detector.main.id
}

output "security_hub_arn" {
  description = "Security Hub ARN"
  value       = aws_securityhub_account.main.arn
}

output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN (for CloudFront association)"
  value       = aws_wafv2_web_acl.cloudfront.arn
}

output "config_recorder_id" {
  description = "AWS Config recorder ID"
  value       = aws_config_configuration_recorder.main.id
}

output "access_analyzer_arn" {
  description = "IAM Access Analyzer ARN"
  value       = aws_accessanalyzer_analyzer.main.arn
}

output "alerts_sns_topic_arn" {
  description = "SNS topic ARN for compliance alerts"
  value       = aws_sns_topic.guardduty_alerts.arn
}
