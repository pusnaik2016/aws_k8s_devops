# =============================================================================
# AWS MODULE VARIABLES
# =============================================================================

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

# --- EKS ---
variable "eks_cluster_version" {
  type = string
}

variable "eks_node_instance_type" {
  type = string
}

variable "eks_node_min" {
  type = number
}

variable "eks_node_max" {
  type = number
}

# --- Aurora ---
variable "aurora_instance_class" {
  type = string
}

variable "aurora_reader_instance_class" {
  type = string
}

# --- ElastiCache ---
variable "elasticache_node_type" {
  type = string
}

# --- Compliance ---
variable "enable_hipaa" {
  type = bool
}

variable "enable_sox" {
  type = bool
}

variable "enable_gdpr" {
  type = bool
}

variable "enable_pci_dss" {
  description = "Enable PCI-DSS compliance controls (WAF, access logging, Config conformance pack)"
  type        = bool
  default     = false
}

# --- Cross-Cloud VPN ---
variable "azure_vpn_gateway_ip" {
  type = string
}

variable "gcp_vpn_gateway_ip" {
  type = string
}

variable "azure_vnet_cidr" {
  type = string
}

variable "gcp_vpc_cidr" {
  type = string
}

variable "vpn_shared_secret_azure" {
  type      = string
  sensitive = true
}

variable "vpn_shared_secret_gcp" {
  type      = string
  sensitive = true
}

variable "common_tags" {
  type = map(string)
}
