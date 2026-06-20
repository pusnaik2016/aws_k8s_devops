variable "project"            { type = string; default = "healthcloud" }
variable "environment"        { type = string }
variable "azure_region"       { type = string; default = "eastus" }
variable "database_subnet_id" { type = string }
variable "private_dns_zone_id" { type = string; default = "" }
variable "db_admin_username"  { type = string; sensitive = true; default = "healthcloud_admin" }
variable "db_admin_password"  { type = string; sensitive = true }
variable "common_tags"        { type = map(string); default = {} }
