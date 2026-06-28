# Azure Storage Module — Variables
variable "project_name" { type = string }
variable "environment" { type = string }
variable "location" { type = string; default = "eastus2" }
variable "common_tags" { type = map(string); default = {} }
variable "storage_cmk_id" { description = "Key Vault key ID for CMK encryption"; type = string }
variable "databricks_identity_id" { description = "User-assigned identity ID for CMK access"; type = string }
variable "vnet_id" { description = "VNet ID for private DNS zone linking"; type = string }
variable "private_endpoint_subnet_id" { description = "Subnet ID for private endpoints"; type = string }
variable "allowed_subnet_ids" { description = "Subnet IDs allowed through storage firewall"; type = list(string); default = [] }
variable "log_analytics_workspace_id" { type = string; default = "" }
