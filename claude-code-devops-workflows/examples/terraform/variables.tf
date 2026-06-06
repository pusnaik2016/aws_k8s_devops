# =============================================================================
# Sample Variables — EKS Cluster
# Purpose: Example for Claude DevOps scanner testing & demonstration
# =============================================================================

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "claude-devops"
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "ClaudeDevOps"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "node_instance_types" {
  description = "EC2 instance types for EKS nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_min_size" {
  description = "Minimum nodes in EKS node group"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum nodes in EKS node group"
  type        = number
  default     = 3
}

variable "node_desired_size" {
  description = "Desired nodes in EKS node group"
  type        = number
  default     = 2
}
