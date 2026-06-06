variable "name" {
  description = "Name prefix for observability resources"
  type        = string
  default     = "agentcore-memory"
}

variable "aws_region" {
  description = "AWS region for dashboard widgets"
  type        = string
}

variable "memory_writer_function_name" {
  description = "Name of the memory writer Lambda"
  type        = string
}

variable "lambda_log_group_name" {
  description = "CloudWatch log group name for the Lambda"
  type        = string
}

variable "sqs_queue_name" {
  description = "Name of the SQS memory queue"
  type        = string
}

variable "dlq_name" {
  description = "Name of the dead letter queue"
  type        = string
}
