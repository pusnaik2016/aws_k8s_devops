# ─────────────────────────────────────────────────────────────────────────────
# EKS Module — Variables
# ─────────────────────────────────────────────────────────────────────────────

variable "name_prefix" {
  description = "Resource naming prefix"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EKS"
  type        = list(string)
}

variable "system_node_instance_type" {
  description = "Instance type for system node group"
  type        = string
  default     = "m6i.large"
}

variable "system_node_count" {
  description = "System node group sizing"
  type = object({
    min     = number
    max     = number
    desired = number
  })
  default = {
    min     = 2
    max     = 4
    desired = 2
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 365
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
