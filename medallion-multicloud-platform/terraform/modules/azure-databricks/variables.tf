# Azure Databricks Module — Variables
variable "project_name" { type = string }
variable "environment" { type = string }
variable "location" { type = string; default = "eastus2" }
variable "common_tags" { type = map(string); default = {} }
variable "vnet_id" { type = string }
variable "databricks_host_subnet_name" { type = string }
variable "databricks_container_subnet_name" { type = string }
variable "databricks_host_nsg_association_id" { type = string }
variable "databricks_container_nsg_association_id" { type = string }
variable "private_endpoint_subnet_id" { type = string }
variable "storage_account_id" { type = string }
variable "storage_account_name" { type = string }
variable "key_vault_id" { type = string }
variable "key_vault_uri" { type = string }
variable "secret_scope_name" { type = string; default = "azure-kv-scope" }
variable "log_analytics_workspace_id" { type = string; default = "" }
