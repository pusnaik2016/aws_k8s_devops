# =============================================================================
# AWS Databricks Module — Variables
# =============================================================================

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment identifier"
  type        = string
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

variable "aws_region" {
  description = "AWS region for workspace deployment"
  type        = string
}

variable "databricks_account_id" {
  description = "Databricks account ID"
  type        = string
}

variable "databricks_cross_account_role_arn" {
  description = "ARN of the Databricks cross-account IAM role"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for Databricks workspace deployment"
  type        = string
}

variable "private_compute_subnet_ids" {
  description = "Subnet IDs for Databricks cluster nodes"
  type        = list(string)
}

variable "databricks_compute_sg_id" {
  description = "Security group ID for Databricks compute nodes"
  type        = string
}

variable "databricks_scc_relay_vpce_id" {
  description = "VPC Endpoint ID for Databricks SCC relay"
  type        = string
}

variable "databricks_workspace_vpce_id" {
  description = "VPC Endpoint ID for Databricks workspace REST API"
  type        = string
}

variable "databricks_kms_key_arn" {
  description = "KMS key ARN for Databricks managed services encryption"
  type        = string
}

variable "databricks_kms_key_id" {
  description = "KMS key ID for DBFS root bucket encryption"
  type        = string
}

variable "s3_kms_key_arn" {
  description = "KMS key ARN for S3 storage encryption"
  type        = string
}

variable "bronze_bucket_name" {
  description = "Name of the Bronze S3 bucket"
  type        = string
}

variable "silver_bucket_name" {
  description = "Name of the Silver S3 bucket"
  type        = string
}

variable "gold_bucket_name" {
  description = "Name of the Gold S3 bucket"
  type        = string
}

variable "secret_scope_name" {
  description = "Name of the Databricks secret scope"
  type        = string
  default     = "aws-sm-scope"
}
