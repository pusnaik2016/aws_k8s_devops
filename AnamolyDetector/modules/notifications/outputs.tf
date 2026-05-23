###############################################################################
# Notifications Module — Outputs
###############################################################################

output "topic_arn" {
  description = "ARN of the SNS cost alerts topic."
  value       = aws_sns_topic.cost_alerts.arn
}

output "topic_name" {
  description = "Name of the SNS topic."
  value       = aws_sns_topic.cost_alerts.name
}

output "subscription_arn" {
  description = "ARN of the email subscription (pending confirmation)."
  value       = aws_sns_topic_subscription.email.arn
}
