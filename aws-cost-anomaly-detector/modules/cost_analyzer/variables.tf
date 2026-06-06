###############################################################################
# Cost Analyzer Module — Variables
###############################################################################

variable "environment" {
  description = "Deployment environment label."
  type        = string
}

variable "aws_region" {
  description = "AWS region for the deployment."
  type        = string
}

variable "dynamodb_table" {
  description = "Name of the DynamoDB table storing cost history."
  type        = string
}

variable "dynamodb_arn" {
  description = "ARN of the DynamoDB table (for IAM policy scoping)."
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic for cost anomaly alerts."
  type        = string
}

variable "bedrock_model_id" {
  description = "Amazon Bedrock model ID to invoke for analysis."
  type        = string
}

variable "zscore_threshold" {
  description = "Z-score threshold above which a cost is considered anomalous."
  type        = number
  default     = 2.5
}

variable "retention_days" {
  description = "Number of days of cost history to fetch and retain."
  type        = number
  default     = 90
}

variable "fetcher_schedule" {
  description = "EventBridge Scheduler cron expression for the cost fetcher Lambda."
  type        = string
  default     = "cron(0 8 * * ? *)"
}

variable "detector_schedule" {
  description = "EventBridge Scheduler cron expression for the anomaly detector Lambda."
  type        = string
  default     = "cron(10 8 * * ? *)"
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period in days."
  type        = number
  default     = 30
}

variable "log_level" {
  description = "Python logging level for Lambda functions."
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR"], var.log_level)
    error_message = "log_level must be one of: DEBUG, INFO, WARNING, ERROR."
  }
}
