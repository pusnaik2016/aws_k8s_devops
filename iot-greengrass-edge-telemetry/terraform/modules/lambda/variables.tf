# -----------------------------------------------------------------------------
# Lambda Module — Variables
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "lambda_exec_role_arn" {
  description = "ARN of the Lambda execution role"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for log encryption"
  type        = string
}
