# -----------------------------------------------------------------------------
# IAM Module — Variables
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "telemetry_bucket_arn" {
  description = "ARN of the S3 bucket for telemetry data"
  type        = string
}

variable "timestream_table_arn" {
  description = "ARN of the Timestream table"
  type        = string
}

variable "alert_lambda_arn" {
  description = "ARN of the alert processor Lambda function"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic for alert notifications"
  type        = string
}
