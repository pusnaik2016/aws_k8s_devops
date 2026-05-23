# -----------------------------------------------------------------------------
# Monitoring Module — Variables
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "kms_key_id" {
  description = "KMS key ID for SNS encryption"
  type        = string
}

variable "alert_email" {
  description = "Email for alert notifications (empty to skip)"
  type        = string
  default     = ""
}

variable "lambda_function_name" {
  description = "Name of the alert processor Lambda function"
  type        = string
}
