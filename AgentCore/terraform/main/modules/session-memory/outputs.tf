output "lambda_function_arn" {
  description = "ARN of the memory writer Lambda"
  value       = aws_lambda_function.memory_writer.arn
}

output "lambda_function_name" {
  description = "Name of the memory writer Lambda"
  value       = aws_lambda_function.memory_writer.function_name
}

output "dynamodb_table_name" {
  description = "Name of the sessions DynamoDB table"
  value       = aws_dynamodb_table.sessions.name
}

output "dynamodb_table_arn" {
  description = "ARN of the sessions DynamoDB table"
  value       = aws_dynamodb_table.sessions.arn
}

output "sqs_queue_url" {
  description = "URL of the SQS memory queue"
  value       = aws_sqs_queue.memory_queue.url
}

output "sqs_queue_arn" {
  description = "ARN of the SQS memory queue"
  value       = aws_sqs_queue.memory_queue.arn
}

output "dlq_arn" {
  description = "ARN of the dead letter queue"
  value       = aws_sqs_queue.dlq.arn
}

output "log_group_name" {
  description = "CloudWatch log group name for the Lambda"
  value       = aws_cloudwatch_log_group.lambda.name
}
