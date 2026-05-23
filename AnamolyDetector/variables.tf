###############################################################################
# Root Variables
###############################################################################

variable "aws_region" {
  description = "AWS region to deploy the stack into."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment label (prod, staging, dev)."
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["prod", "staging", "dev"], var.environment)
    error_message = "environment must be one of: prod, staging, dev."
  }
}

variable "alert_email" {
  description = "Email address that will receive cost anomaly alerts via SNS."
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email))
    error_message = "alert_email must be a valid email address."
  }
}

variable "bedrock_model_id" {
  description = "Amazon Bedrock model ID to use for anomaly analysis."
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20241022-v2:0"
}

variable "zscore_threshold" {
  description = <<-EOT
    Z-score threshold for anomaly detection.
    2.0 = ~4.5% of observations flagged (more sensitive).
    2.5 = ~1.2% of observations flagged (balanced default).
    3.0 = ~0.3% of observations flagged (less sensitive).
  EOT
  type        = number
  default     = 2.5

  validation {
    condition     = var.zscore_threshold >= 1.5 && var.zscore_threshold <= 5.0
    error_message = "zscore_threshold must be between 1.5 and 5.0."
  }
}

variable "fetcher_schedule" {
  description = "EventBridge cron expression for the Cost Fetcher Lambda (UTC)."
  type        = string
  default     = "cron(0 8 * * ? *)"
}

variable "detector_schedule" {
  description = "EventBridge cron expression for the Anomaly Detector Lambda (UTC, 10 min after fetcher)."
  type        = string
  default     = "cron(10 8 * * ? *)"
}

variable "log_retention_days" {
  description = "CloudWatch log group retention in days."
  type        = number
  default     = 30
}

variable "log_level" {
  description = "Python logging level for Lambda functions (DEBUG, INFO, WARNING, ERROR)."
  type        = string
  default     = "INFO"
}
