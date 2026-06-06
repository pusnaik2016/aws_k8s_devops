# ==============================================================================
# KMS Module — Input Variables
# ==============================================================================

variable "project_name" {
  description = "Project name used as prefix for KMS key aliases"
  type        = string
}

variable "aws_region" {
  description = "AWS region for service-specific key policies"
  type        = string
}

variable "account_id" {
  description = "AWS account ID for KMS key policies"
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all KMS resources"
  type        = map(string)
  default     = {}
}
