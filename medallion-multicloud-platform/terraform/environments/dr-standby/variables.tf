# DR Standby Environment — Variables
variable "project_name" { type = string; default = "medallion-platform" }
variable "environment" { type = string; default = "dr-standby" }
variable "azure_location" { type = string; default = "eastus2" }
variable "azure_subscription_id" { type = string }
variable "azure_vnet_cidr" { type = string; default = "10.1.0.0/16" }
variable "common_tags" {
  type    = map(string)
  default = { Project = "medallion-platform"; Environment = "dr-standby"; Compliance = "hipaa-soc2-pci"; ManagedBy = "terraform" }
}
