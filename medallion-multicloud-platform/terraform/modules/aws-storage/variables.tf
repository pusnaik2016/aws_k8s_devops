# =============================================================================
# AWS Storage Module — Variables
# =============================================================================

variable "project_name" {
  description = "Project name used in resource naming"
  type        = string
}

variable "environment" {
  description = "Environment identifier"
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}

variable "s3_kms_key_id" {
  description = "KMS key ID for S3 medallion bucket encryption"
  type        = string
}

variable "logs_kms_key_id" {
  description = "KMS key ID for audit log bucket encryption"
  type        = string
}

variable "s3_vpc_endpoint_id" {
  description = "VPC endpoint ID for S3 (used in bucket policy to restrict access)"
  type        = string
}
