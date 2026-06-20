variable "project"           { type = string; default = "healthcloud" }
variable "environment"       { type = string }
variable "azure_region"      { type = string; default = "eastus" }
variable "vnet_cidr"         { type = string; default = "10.1.0.0/16" }
variable "aws_vpc_cidr"      { type = string; default = "10.0.0.0/16" }
variable "aws_vpn_gateway_ip" { type = string; default = "" }
variable "vpn_shared_key"    { type = string; sensitive = true; default = "" }
variable "common_tags"       { type = map(string); default = {} }
