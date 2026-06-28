# Cross-Cloud Transit Module — Variables
variable "project_name" { type = string }
variable "environment" { type = string }
variable "common_tags" { type = map(string); default = {} }
variable "azure_location" { type = string; default = "eastus2" }
variable "aws_vpc_cidr" { type = string }
variable "aws_vpn_gateway_id" { type = string }
variable "aws_bgp_asn" { type = number; default = 64512 }
variable "azure_bgp_asn" { type = number; default = 65515 }
variable "azure_gateway_public_ip" { type = string }
variable "azure_vnet_gateway_id" { type = string }
variable "vpn_shared_key" { description = "IPSec pre-shared key (store in Secrets Manager)"; type = string; sensitive = true }
