###############################################################################
# Outputs
###############################################################################

output "lambda_function_name" {
  description = "Name of the deployed Lambda tagger function."
  value       = aws_lambda_function.tagger.function_name
}

output "lambda_function_arn" {
  description = "ARN of the deployed Lambda tagger function."
  value       = aws_lambda_function.tagger.arn
}

output "eventbridge_rule_arn" {
  description = "ARN of the nightly EventBridge rule."
  value       = aws_cloudwatch_event_rule.nightly.arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS digest topic."
  value       = aws_sns_topic.digest.arn
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for Lambda output."
  value       = aws_cloudwatch_log_group.tagger.name
}
