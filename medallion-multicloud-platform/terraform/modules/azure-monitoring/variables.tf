# Azure Monitoring Module — Variables & Outputs
variable "project_name" { type = string }
variable "environment" { type = string }
variable "location" { type = string; default = "eastus2" }
variable "common_tags" { type = map(string); default = {} }
variable "alert_email_addresses" { type = list(string); default = [] }
variable "monitored_resource_ids" { description = "Resource IDs to monitor"; type = list(string); default = [] }
