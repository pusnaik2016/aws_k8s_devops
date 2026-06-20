variable "project"                   { type = string; default = "healthcloud" }
variable "environment"               { type = string }
variable "azure_region"              { type = string; default = "eastus" }
variable "kubernetes_version"        { type = string; default = "1.30" }
variable "aks_subnet_id"             { type = string }
variable "log_analytics_workspace_id" { type = string; default = "" }
variable "common_tags"               { type = map(string); default = {} }
