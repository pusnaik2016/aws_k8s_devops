# -----------------------------------------------------------------------------
# Storage Module — Variables
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

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
}

variable "s3_transition_ia_days" {
  description = "Days before transitioning to Infrequent Access"
  type        = number
  default     = 30
}

variable "s3_transition_glacier_days" {
  description = "Days before transitioning to Glacier"
  type        = number
  default     = 90
}

variable "s3_expiration_days" {
  description = "Days before object expiration"
  type        = number
  default     = 2555
}

variable "timestream_memory_retention_hours" {
  description = "Hours for Timestream memory store retention"
  type        = number
  default     = 24
}

variable "timestream_magnetic_retention_days" {
  description = "Days for Timestream magnetic store retention"
  type        = number
  default     = 365
}
