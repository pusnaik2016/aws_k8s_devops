# =============================================================================
# AWS Monitoring Module — Outputs
# =============================================================================

output "compliance_sns_topic_arn" {
  description = "ARN of the compliance alerts SNS topic"
  value       = aws_sns_topic.compliance_alerts.arn
}

output "dashboard_name" {
  description = "Name of the compliance CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.compliance.dashboard_name
}
