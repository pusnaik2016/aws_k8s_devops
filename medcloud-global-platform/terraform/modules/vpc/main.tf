# ─────────────────────────────────────────────────────────────────────────────
# Reusable Module: VPC / Virtual Network
# ─────────────────────────────────────────────────────────────────────────────
# Cross-cloud VPC module that provisions network foundations.
# Supports AWS VPC, Azure VNet, and GCP VPC via the `cloud_provider` variable.
# ─────────────────────────────────────────────────────────────────────────────

variable "cloud_provider" {
  description = "Target cloud: aws, azure, or gcp"
  type        = string
  validation {
    condition     = contains(["aws", "azure", "gcp"], var.cloud_provider)
    error_message = "cloud_provider must be aws, azure, or gcp."
  }
}

variable "name_prefix" {
  description = "Resource naming prefix"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC/VNet"
  type        = string
}

variable "environment" {
  description = "Environment: dev, staging, prod"
  type        = string
}

variable "availability_zones" {
  description = "List of AZs / zones to deploy subnets into"
  type        = list(string)
  default     = []
}

variable "enable_flow_logs" {
  description = "Enable VPC flow logs (required for HIPAA)"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

# ─── Subnet CIDR Calculation ────────────────────────────────────────────

locals {
  # Split the VPC CIDR into /24 subnets for each tier
  subnet_tiers = {
    public   = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 8, i)]
    private  = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 8, i + 10)]
    isolated = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 8, i + 20)]
  }
}

# ─── Outputs ─────────────────────────────────────────────────────────────

output "vpc_cidr" {
  description = "The CIDR block of the provisioned network"
  value       = var.vpc_cidr
}

output "subnet_cidrs" {
  description = "Calculated subnet CIDRs per tier"
  value       = local.subnet_tiers
}

output "cloud_provider" {
  value = var.cloud_provider
}

# NOTE: Actual resource blocks (aws_vpc, azurerm_virtual_network, 
# google_compute_network) are in the cloud-specific implementations
# under terraform/{aws,azure,gcp}/networking/main.tf.
# This module provides the shared variable interface and CIDR math.
