# ─────────────────────────────────────────────────────────────
# Compute Module — Variables
# ─────────────────────────────────────────────────────────────

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EKS"
  type        = list(string)
}

variable "eks_cluster_role_arn" {
  description = "IAM role ARN for EKS cluster"
  type        = string
}

variable "eks_node_group_role_arn" {
  description = "IAM role ARN for EKS node group"
  type        = string
}

variable "eks_nodes_security_group_id" {
  description = "Security group ID for EKS nodes"
  type        = string
}

variable "kms_eks_key_arn" {
  description = "KMS key ARN for EKS secrets encryption"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "node_instance_types" {
  description = "EC2 instance types for node group"
  type        = list(string)
  default     = ["m6g.large"]
}

variable "node_min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 10
}

variable "node_desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 2
}

variable "tags" {
  type    = map(string)
  default = {}
}
