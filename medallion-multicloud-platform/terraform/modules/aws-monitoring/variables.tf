# =============================================================================
# AWS Monitoring Module — Variables
# =============================================================================

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "common_tags" {
  type    = map(string)
  default = {}
}

variable "aws_region" {
  type = string
}

variable "logs_kms_key_id" {
  description = "KMS key ID for SNS topic encryption"
  type        = string
}

variable "cloudtrail_log_group_name" {
  description = "CloudWatch log group name for CloudTrail events"
  type        = string
}

variable "alert_email_addresses" {
  description = "Email addresses for compliance violation alerts"
  type        = list(string)
  default     = []
}
