# ─────────────────────────────────────────────────────────────────────────────
# Global Variables — Shared across all cloud providers
# ─────────────────────────────────────────────────────────────────────────────

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "medcloud"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "compliance_frameworks" {
  description = "Compliance frameworks this deployment must satisfy"
  type        = list(string)
  default     = ["HIPAA", "GDPR", "PCI-DSS"]
}

# ─── Common Tags ─────────────────────────────────────────────────────────────

variable "common_tags" {
  description = "Tags applied to all resources across all clouds"
  type        = map(string)
  default = {
    Project     = "medcloud-global"
    ManagedBy   = "terraform"
    Compliance  = "HIPAA,GDPR,PCI-DSS"
    CostCenter  = "healthcare-platform"
  }
}

# ─── AWS Variables ───────────────────────────────────────────────────────────

variable "aws_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_secondary_region" {
  description = "Secondary AWS region for DR"
  type        = string
  default     = "eu-west-1"
}

variable "aws_vpc_cidr" {
  description = "CIDR block for AWS VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# ─── Azure Variables ─────────────────────────────────────────────────────────

variable "azure_location" {
  description = "Primary Azure region"
  type        = string
  default     = "eastus"
}

variable "azure_secondary_location" {
  description = "Secondary Azure region for DR"
  type        = string
  default     = "westeurope"
}

variable "azure_vnet_cidr" {
  description = "CIDR block for Azure VNet"
  type        = string
  default     = "10.1.0.0/16"
}

# ─── GCP Variables ───────────────────────────────────────────────────────────

variable "gcp_project_id" {
  description = "GCP project ID"
  type        = string
  default     = "medcloud-global-platform"
}

variable "gcp_region" {
  description = "Primary GCP region"
  type        = string
  default     = "us-central1"
}

variable "gcp_secondary_region" {
  description = "Secondary GCP region"
  type        = string
  default     = "europe-west1"
}

variable "gcp_vpc_cidr" {
  description = "CIDR block for GCP VPC subnets"
  type        = string
  default     = "10.2.0.0/16"
}

# ─── Cross-Cloud Networking ─────────────────────────────────────────────────

variable "cross_cloud_vpn_config" {
  description = "Cross-cloud VPN tunnel configuration"
  type = object({
    aws_to_azure_enabled = bool
    aws_to_gcp_enabled   = bool
    azure_to_gcp_enabled = bool
    shared_secret_key    = string
  })
  default = {
    aws_to_azure_enabled = true
    aws_to_gcp_enabled   = true
    azure_to_gcp_enabled = true
    shared_secret_key    = "" # Set via TF_VAR or secrets manager
  }
  sensitive = true
}

# ─── Kubernetes Configuration ────────────────────────────────────────────────

variable "kubernetes_version" {
  description = "Kubernetes version for all clusters"
  type        = string
  default     = "1.29"
}

variable "node_instance_type" {
  description = "Default node instance type per cloud"
  type = object({
    aws   = string
    azure = string
    gcp   = string
  })
  default = {
    aws   = "m6i.xlarge"
    azure = "Standard_D4s_v5"
    gcp   = "e2-standard-4"
  }
}

variable "node_count" {
  description = "Node count per cloud (min/max for autoscaling)"
  type = object({
    min = number
    max = number
  })
  default = {
    min = 2
    max = 10
  }
}
