# =============================================================================
# Azure Networking Module — Variables
# =============================================================================

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus2"
}

variable "vnet_cidr" {
  description = "CIDR block for the VNet"
  type        = string
  default     = "10.1.0.0/16"
}

variable "common_tags" {
  type    = map(string)
  default = {}
}

variable "enable_cross_cloud_transit" {
  type    = bool
  default = true
}

variable "expressroute_provider" {
  description = "ExpressRoute service provider name"
  type        = string
  default     = "Equinix"
}

variable "expressroute_peering_location" {
  description = "ExpressRoute peering location"
  type        = string
  default     = "Washington DC"
}

variable "expressroute_bandwidth_mbps" {
  description = "ExpressRoute circuit bandwidth in Mbps"
  type        = number
  default     = 200
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for traffic analytics"
  type        = string
  default     = ""
}

variable "log_analytics_workspace_resource_id" {
  description = "Log Analytics workspace resource ID"
  type        = string
  default     = ""
}

variable "flow_log_storage_account_id" {
  description = "Storage account ID for NSG flow logs"
  type        = string
  default     = ""
}
