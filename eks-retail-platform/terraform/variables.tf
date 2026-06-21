# ─────────────────────────────────────────────────────────────────────────────
# EKS Retail Platform — Shared Variables
# ─────────────────────────────────────────────────────────────────────────────

# ─── Project ─────────────────────────────────────────────────────────────────

variable "project_name" {
  description = "Project name used as prefix for all resources"
  type        = string
  default     = "eks-retail"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

# ─── Networking ──────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# ─── EKS ─────────────────────────────────────────────────────────────────────

variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.31"
}

variable "system_node_instance_type" {
  description = "Instance type for the system node group (runs Karpenter, CoreDNS)"
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

# ─── Database ────────────────────────────────────────────────────────────────

variable "db_instance_class" {
  description = "Aurora PostgreSQL instance class (or serverless min/max ACU)"
  type = object({
    min_acu = number
    max_acu = number
  })
  default = {
    min_acu = 0.5
    max_acu = 16
  }
}

variable "db_backup_retention_days" {
  description = "Number of days to retain automated DB backups"
  type        = number
  default     = 35 # HIPAA requires minimum 6 years for some data
}

# ─── Security ────────────────────────────────────────────────────────────────

variable "enable_waf" {
  description = "Enable AWS WAF on ALB"
  type        = bool
  default     = true
}

variable "enable_shield" {
  description = "Enable AWS Shield Advanced (DDoS protection)"
  type        = bool
  default     = false
}

variable "enable_guardduty" {
  description = "Enable Amazon GuardDuty (threat detection)"
  type        = bool
  default     = true
}

variable "enable_security_hub" {
  description = "Enable AWS Security Hub (compliance dashboard)"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days (SOC2/HIPAA: min 365)"
  type        = number
  default     = 365
}

# ─── Tags ────────────────────────────────────────────────────────────────────

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Project    = "eks-retail-platform"
    ManagedBy  = "terraform"
    Compliance = "PCI-DSS,SOC2,HIPAA,GDPR"
  }
}
