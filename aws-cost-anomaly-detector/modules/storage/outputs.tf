###############################################################################
# Storage Module — Outputs
###############################################################################

output "table_name" {
  description = "Full DynamoDB table name (with environment suffix)."
  value       = aws_dynamodb_table.cost_history.name
}

output "table_arn" {
  description = "ARN of the DynamoDB cost history table."
  value       = aws_dynamodb_table.cost_history.arn
}

output "retention_days" {
  description = "Configured retention period in days."
  value       = var.retention_days
}
