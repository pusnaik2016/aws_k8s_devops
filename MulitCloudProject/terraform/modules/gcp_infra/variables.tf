# =============================================================================
# GCP MODULE VARIABLES
# =============================================================================

variable "project_name" { type = string }
variable "environment" { type = string }
variable "project_id" { type = string }
variable "region" { type = string }
variable "vpc_cidr" { type = string }

# GKE
variable "gke_node_machine_type" { type = string }
variable "gke_node_min" { type = number }
variable "gke_node_max" { type = number }

# AlloyDB
variable "alloydb_cpu_count" { type = number }

# Compliance
variable "enable_hipaa" { type = bool }
variable "enable_sox" { type = bool }
variable "enable_gdpr" { type = bool }
variable "enable_pci_dss" {
  description = "Enable PCI-DSS compliance controls (org policies, network segmentation, encryption)"
  type        = bool
  default     = false
}

# Cross-Cloud VPN
variable "aws_vpn_gateway_ip" { type = string }
variable "azure_vpn_gateway_ip" { type = string }
variable "aws_vpc_cidr" { type = string }
variable "azure_vnet_cidr" { type = string }
variable "vpn_shared_secret_aws" {
  type      = string
  sensitive = true
}
variable "vpn_shared_secret_azure" {
  type      = string
  sensitive = true
}

variable "common_labels" { type = map(string) }
