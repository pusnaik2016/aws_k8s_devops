# ─────────────────────────────────────────────────────────────────────────────
# VPC Module — Variables
# ─────────────────────────────────────────────────────────────────────────────

variable "name_prefix" {
  description = "Resource naming prefix"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name (for subnet tagging)"
  type        = string
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway (cost savings for non-prod)"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "VPC Flow Logs retention in days"
  type        = number
  default     = 365
}

variable "kms_key_arn" {
  description = "KMS key ARN for encrypting CloudWatch logs"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
