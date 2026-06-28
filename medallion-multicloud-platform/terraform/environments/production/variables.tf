# Production Environment — Variables
variable "project_name" { type = string; default = "medallion-platform" }
variable "environment" { type = string; default = "production" }
variable "aws_region" { type = string; default = "us-east-1" }
variable "aws_vpc_cidr" { type = string; default = "10.0.0.0/16" }
variable "azure_location" { type = string; default = "eastus2" }
variable "azure_subscription_id" { type = string }
variable "databricks_account_id" { type = string }
variable "github_org" { type = string; default = "your-org" }
variable "github_repo" { type = string; default = "medallion-multicloud-platform" }
variable "alert_email_addresses" { type = list(string); default = [] }

variable "common_tags" {
  type = map(string)
  default = {
    Project     = "medallion-platform"
    Environment = "production"
    Compliance  = "hipaa-soc2-pci"
    ManagedBy   = "terraform"
  }
}
