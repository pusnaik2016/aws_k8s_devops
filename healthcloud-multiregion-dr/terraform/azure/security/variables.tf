variable "project"       { type = string; default = "healthcloud" }
variable "environment"   { type = string }
variable "azure_region"  { type = string; default = "eastus" }
variable "common_tags"   { type = map(string); default = {} }
