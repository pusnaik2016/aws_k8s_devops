# =============================================================================
# AWS Networking Module — Variables
# =============================================================================

variable "project_name" {
  description = "Project name used in resource naming"
  type        = string
}

variable "environment" {
  description = "Environment identifier (e.g., production, dr-standby)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}

variable "logs_kms_key_arn" {
  description = "ARN of the KMS key used to encrypt CloudWatch log groups"
  type        = string
}

variable "databricks_scc_relay_service_id" {
  description = "Databricks Secure Cluster Connectivity (SCC) relay VPC Endpoint Service ID"
  type        = string
  default     = "0123456789abcdef0" # Replace with actual service ID for your region
}

variable "databricks_workspace_service_id" {
  description = "Databricks workspace REST API VPC Endpoint Service ID"
  type        = string
  default     = "0123456789abcdef1" # Replace with actual service ID for your region
}

variable "enable_cross_cloud_transit" {
  description = "Enable Direct Connect gateway for AWS-Azure cross-cloud connectivity"
  type        = bool
  default     = true
}

variable "dx_amazon_side_asn" {
  description = "Amazon-side BGP ASN for the Direct Connect Gateway"
  type        = number
  default     = 64512
}
