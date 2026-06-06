# =============================================================================
# BOOTSTRAP — Variables
# =============================================================================

variable "project_name" {
  description = "Project name used for naming state backend resources"
  type        = string
  default     = "multicloud-clearing-engine"
}

# --- AWS ---
variable "aws_region" {
  description = "AWS region for the S3 state bucket and DynamoDB lock table"
  type        = string
  default     = "us-east-1"
}

# --- Azure ---
variable "azure_region" {
  description = "Azure region for the storage account"
  type        = string
  default     = "eastus"
}

variable "azure_subscription_id" {
  description = "Azure subscription ID"
  type        = string
  sensitive   = true
}

# --- GCP ---
variable "gcp_project_id" {
  description = "GCP project ID for the GCS state bucket"
  type        = string
  default     = "enterprise-compliance-analytics"
}

variable "gcp_region" {
  description = "GCP region for the GCS state bucket"
  type        = string
  default     = "us-central1"
}
