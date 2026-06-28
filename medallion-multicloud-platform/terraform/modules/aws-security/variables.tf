# =============================================================================
# AWS Security Module — Variables
# =============================================================================

variable "project_name" {
  description = "Project name used in resource naming"
  type        = string
}

variable "environment" {
  description = "Environment identifier (e.g., production, dr-standby)"
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}

variable "databricks_account_id" {
  description = "Databricks account ID for cross-account trust"
  type        = string
}

variable "databricks_cross_account_role_arn" {
  description = "ARN of the Databricks cross-account IAM role (self-referencing for KMS policy)"
  type        = string
  default     = "*" # Will be refined post-creation
}

variable "audit_log_bucket_name" {
  description = "Name of the S3 bucket for CloudTrail audit logs"
  type        = string
}

variable "github_org" {
  description = "GitHub organization name for OIDC federation"
  type        = string
  default     = "your-org"
}

variable "github_repo" {
  description = "GitHub repository name for OIDC federation"
  type        = string
  default     = "medallion-multicloud-platform"
}

variable "create_github_oidc_provider" {
  description = "Whether to create the GitHub OIDC provider (set false if already exists in account)"
  type        = bool
  default     = true
}
