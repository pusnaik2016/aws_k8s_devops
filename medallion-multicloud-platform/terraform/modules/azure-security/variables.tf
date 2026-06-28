# Azure Security Module — Variables
variable "project_name" { type = string }
variable "environment" { type = string }
variable "location" { type = string; default = "eastus2" }
variable "common_tags" { type = map(string); default = {} }

variable "allowed_subnet_ids" {
  description = "Subnet IDs allowed to access Key Vault"
  type        = list(string)
  default     = []
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for diagnostic settings"
  type        = string
  default     = ""
}
