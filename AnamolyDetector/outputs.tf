###############################################################################
# Root Outputs
###############################################################################

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table storing cost history."
  value       = module.storage.table_name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table."
  value       = module.storage.table_arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic used for alerts."
  value       = module.notifications.topic_arn
}

output "cost_fetcher_lambda_arn" {
  description = "ARN of the Cost Fetcher Lambda function."
  value       = module.cost_analyzer.fetcher_lambda_arn
}

output "anomaly_detector_lambda_arn" {
  description = "ARN of the Anomaly Detector Lambda function."
  value       = module.cost_analyzer.detector_lambda_arn
}

output "bedrock_model_id" {
  description = "Bedrock model ID in use."
  value       = module.bedrock_config.model_id
}

output "deployment_summary" {
  description = "Human-readable summary of deployed resources."
  value = <<-EOT
    ╔══════════════════════════════════════════════════════════╗
    ║        AWS Cost Anomaly Detector — Deployment Summary   ║
    ╠══════════════════════════════════════════════════════════╣
    ║  Region      : ${var.aws_region}
    ║  Environment : ${var.environment}
    ║  Alert Email : ${var.alert_email}
    ║  Z-Threshold : ${var.zscore_threshold}
    ║  Model       : ${var.bedrock_model_id}
    ║  Fetcher     : ${var.fetcher_schedule}
    ║  Detector    : ${var.detector_schedule}
    ╚══════════════════════════════════════════════════════════╝
    IMPORTANT: Check your email and confirm the SNS subscription!
  EOT
}
