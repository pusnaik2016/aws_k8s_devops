# ============================================================================
# Global Variables — HealthCloud Multi-Region DR Platform
# ============================================================================

variable "project" {
  description = "Project name"
  type        = string
  default     = "healthcloud"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "AWS primary region"
  type        = string
  default     = "us-east-1"
}

variable "azure_region" {
  description = "Azure DR region"
  type        = string
  default     = "eastus"
}

variable "aws_vpc_cidr" {
  description = "AWS VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azure_vnet_cidr" {
  description = "Azure VNet CIDR"
  type        = string
  default     = "10.1.0.0/16"
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS and AKS"
  type        = string
  default     = "1.30"
}

variable "db_master_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

variable "redis_auth_token" {
  description = "Redis authentication token"
  type        = string
  sensitive   = true
}

variable "alert_emails" {
  description = "Email addresses for alerts"
  type        = list(string)
  default     = []
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Project            = "healthcloud"
    ManagedBy          = "terraform"
    Owner              = "platform-team"
    Compliance         = "hipaa"
    DataClassification = "confidential"
  }
}
