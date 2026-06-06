# ─────────────────────────────────────────────────────────────
# Security Module — Variables
# ─────────────────────────────────────────────────────────────

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for security groups"
  type        = string
}

variable "vpc_cidr_block" {
  description = "VPC CIDR block for internal access rules"
  type        = string
}

variable "github_org_repo" {
  description = "GitHub org/repo for OIDC (e.g., 'pusnaik2016/OmniPresenseAI')"
  type        = string
  default     = "pusnaik2016/OmniPresenseAI"
}

variable "eks_cluster_name" {
  description = "EKS cluster name (for security group naming)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
