# ─────────────────────────────────────────────────────────────
# AI Governance Module — Variables
# ─────────────────────────────────────────────────────────────

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (prod, staging)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "kms_s3_key_arn" {
  description = "KMS key ARN for S3/CloudWatch encryption"
  type        = string
}

variable "alert_sns_topic_arn" {
  description = "SNS topic ARN for AI monitoring alerts"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
