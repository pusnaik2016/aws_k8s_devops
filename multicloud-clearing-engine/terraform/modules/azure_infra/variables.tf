# =============================================================================
# AZURE MODULE VARIABLES
# =============================================================================

variable "project_name" { type = string }
variable "environment" { type = string }
variable "domain_name" { type = string }
variable "location" { type = string }
variable "vnet_address_space" { type = string }

# AKS
variable "aks_node_vm_size" { type = string }
variable "aks_system_node_min" { type = number }
variable "aks_system_node_max" { type = number }
variable "aks_user_node_min" { type = number }
variable "aks_user_node_max" { type = number }

# SQL
variable "sql_sku" { type = string }

# Compliance
variable "enable_hipaa" { type = bool }
variable "enable_sox" { type = bool }
variable "enable_gdpr" { type = bool }
variable "enable_pci_dss" {
  description = "Enable PCI-DSS compliance controls (Azure Policy, Defender, NSG hardening)"
  type        = bool
  default     = false
}

# Azure AD
variable "azure_ad_admin_group_name" { type = string }
variable "azure_ad_dev_group_name" { type = string }
variable "azure_ad_compliance_group_name" { type = string }
variable "azure_ad_admin_users" { type = list(string) }
variable "azure_tenant_id" {
  type      = string
  sensitive = true
}

# Cross-Cloud VPN
variable "aws_vpn_gateway_ip" { type = string }
variable "gcp_vpn_gateway_ip" { type = string }
variable "aws_vpc_cidr" { type = string }
variable "gcp_vpc_cidr" { type = string }
variable "vpn_shared_secret_aws" {
  type      = string
  sensitive = true
}
variable "vpn_shared_secret_gcp" {
  type      = string
  sensitive = true
}

variable "common_tags" { type = map(string) }
