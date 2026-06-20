variable "project"         { type = string; default = "healthcloud" }
variable "environment"     { type = string }
variable "azure_region"    { type = string; default = "eastus" }
variable "alert_emails"    { type = list(string); default = [] }
variable "aks_cluster_id"  { type = string; default = "" }
variable "common_tags"     { type = map(string); default = {} }
