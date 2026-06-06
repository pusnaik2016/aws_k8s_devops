###############################################################################
# Cost Analyzer Module — Outputs
###############################################################################

output "fetcher_lambda_arn" {
  description = "ARN of the Cost Fetcher Lambda function."
  value       = aws_lambda_function.cost_fetcher.arn
}

output "fetcher_lambda_name" {
  description = "Name of the Cost Fetcher Lambda function."
  value       = aws_lambda_function.cost_fetcher.function_name
}

output "detector_lambda_arn" {
  description = "ARN of the Anomaly Detector Lambda function."
  value       = aws_lambda_function.anomaly_detector.arn
}

output "detector_lambda_name" {
  description = "Name of the Anomaly Detector Lambda function."
  value       = aws_lambda_function.anomaly_detector.function_name
}

output "fetcher_log_group" {
  description = "CloudWatch log group for the Cost Fetcher."
  value       = aws_cloudwatch_log_group.cost_fetcher.name
}

output "detector_log_group" {
  description = "CloudWatch log group for the Anomaly Detector."
  value       = aws_cloudwatch_log_group.anomaly_detector.name
}
