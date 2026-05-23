# ==============================================================================
# EKS Module — Input Variables
# ==============================================================================

variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "eks_cluster_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.31"
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EKS control plane and nodes"
  type        = list(string)
}

variable "eks_cluster_sg_id" {
  description = "Security group ID for EKS cluster control plane"
  type        = string
}

variable "eks_kms_key_arn" {
  description = "KMS key ARN for EKS secrets encryption"
  type        = string
}

variable "ebs_kms_key_arn" {
  description = "KMS key ARN for EBS volume encryption"
  type        = string
}

variable "bootstrap_instance_type" {
  description = "Instance type for bootstrap managed node group"
  type        = string
  default     = "t3.medium"
}

variable "bootstrap_min_size" {
  description = "Minimum nodes in bootstrap node group"
  type        = number
  default     = 2
}

variable "bootstrap_desired_size" {
  description = "Desired nodes in bootstrap node group"
  type        = number
  default     = 2
}

variable "bootstrap_max_size" {
  description = "Maximum nodes in bootstrap node group"
  type        = number
  default     = 4
}

variable "node_disk_size" {
  description = "Root EBS volume size for worker nodes (GB)"
  type        = number
  default     = 50
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
