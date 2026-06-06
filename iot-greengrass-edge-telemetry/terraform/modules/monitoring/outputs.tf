# -----------------------------------------------------------------------------
# Monitoring Module — Outputs
# -----------------------------------------------------------------------------

output "sns_topic_arn" {
  description = "ARN of the IoT alerts SNS topic"
  value       = aws_sns_topic.alerts.arn
}

output "sns_topic_name" {
  description = "Name of the IoT alerts SNS topic"
  value       = aws_sns_topic.alerts.name
}

output "dashboard_url" {
  description = "URL of the CloudWatch IoT overview dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.iot_overview.dashboard_name}"
}
