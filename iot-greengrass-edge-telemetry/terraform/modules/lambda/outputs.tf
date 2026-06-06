# -----------------------------------------------------------------------------
# Lambda Module — Outputs
# -----------------------------------------------------------------------------

output "alert_function_arn" {
  description = "ARN of the alert processor Lambda"
  value       = aws_lambda_function.alert_processor.arn
}

output "alert_function_name" {
  description = "Name of the alert processor Lambda"
  value       = aws_lambda_function.alert_processor.function_name
}
