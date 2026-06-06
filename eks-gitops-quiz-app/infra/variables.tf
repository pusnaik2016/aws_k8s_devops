# =============================================================================
# Variables Configuration (Merged)
# Project: 3-Tier EKS Application
# Author: Pushparaj Naik
# =============================================================================

# --- General ---
variable "aws_region" {
  description = "Primary AWS region for deployment"
  type        = string
  default     = "ap-south-1"
}

variable "dr_region" {
  description = "Disaster Recovery AWS region for cross-region backups"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "3TierEKS"
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
  description = "Prefix to be used for all resources"
  type        = string
  default     = "pushparaj"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# --- GitHub OIDC ---
variable "github_repositories" {
  description = "List of GitHub repositories to grant OIDC access to"
  type = list(object({
    org    = string
    repo   = string
    branch = string
  }))
  default = [
    {
      org    = "pushparajnaik"
      repo   = "3Tier_EKS_React"
      branch = "*"
    }
  ]
}

# --- EKS ---
variable "eks_node_instance_types" {
  description = "EC2 instance types for EKS managed node groups"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_node_min_size" {
  description = "Minimum number of EKS worker nodes"
  type        = number
  default     = 1
}

variable "eks_node_max_size" {
  description = "Maximum number of EKS worker nodes"
  type        = number
  default     = 3
}

variable "eks_node_desired_size" {
  description = "Desired number of EKS worker nodes"
  type        = number
  default     = 2
}

# --- RDS ---
variable "db_default_settings" {
  description = "RDS PostgreSQL database configuration"
  type = object({
    allocated_storage       = number
    max_allocated_storage   = number
    engine_version          = number
    instance_class          = string
    backup_retention_period = number
    db_name                 = string
    ca_cert_name            = string
    db_admin_username       = string
  })
  default = {
    allocated_storage       = 30
    max_allocated_storage   = 50
    engine_version          = 14.15
    instance_class          = "db.t3.micro"
    backup_retention_period = 7 # 7 days for compliance (GDPR/SOC2)
    db_name                 = "devops_learning"
    ca_cert_name            = "rds-ca-rsa2048-g1"
    db_admin_username       = "postgres"
  }
}

# --- Feature Toggles ---
variable "enable_waf" {
  description = "Enable AWS WAF for ALB protection"
  type        = bool
  default     = true
}

variable "enable_guardduty" {
  description = "Enable Amazon GuardDuty for threat detection"
  type        = bool
  default     = true
}

variable "enable_dr" {
  description = "Enable Disaster Recovery (cross-region RDS snapshots)"
  type        = bool
  default     = true
}

# --- ArgoCD / GitOps ---
variable "enable_argocd" {
  description = "Enable ArgoCD deployment for GitOps workflow"
  type        = bool
  default     = true
}

variable "argocd_chart_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "7.7.5"
}

variable "argocd_namespace" {
  description = "Kubernetes namespace for ArgoCD"
  type        = string
  default     = "argocd"
}

variable "gitops_repo_url" {
  description = "Git repository URL for ArgoCD to monitor"
  type        = string
  default     = "https://github.com/pushparajnaik/3Tier_EKS_React.git"
}

variable "gitops_target_revision" {
  description = "Git branch/tag/commit for ArgoCD to track"
  type        = string
  default     = "main"
}

# --- External Secrets ---
variable "enable_external_secrets" {
  description = "Enable External Secrets Operator"
  type        = bool
  default     = true
}

variable "external_secrets_chart_version" {
  description = "External Secrets Operator Helm chart version"
  type        = string
  default     = "0.10.7"
}
