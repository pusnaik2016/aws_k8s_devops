terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws     = { source = "hashicorp/aws",    version = "~> 5.40" }
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.90" }
    google  = { source = "hashicorp/google",  version = "~> 5.20" }
  }
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
  default_tags { tags = var.common_tags }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
  subscription_id = var.azure_subscription_id
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

variable "project_name"         { default = "medcloud" }
variable "environment"          { default = "prod" }
variable "aws_region"           { default = "us-east-1" }
variable "azure_subscription_id" { type = string; default = ""; sensitive = true }
variable "azure_location"       { default = "eastus" }
variable "gcp_project_id"       { default = "medcloud-global-prod" }
variable "gcp_region"           { default = "us-central1" }
variable "common_tags"          { type = map(string); default = {} }
