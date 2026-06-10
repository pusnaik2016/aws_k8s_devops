# ─────────────────────────────────────────────────────────────────────────────
# Dev Environment — Root Module (orchestrates all cloud modules)
# ─────────────────────────────────────────────────────────────────────────────
# Usage:
#   cd terraform/environments/dev
#   terraform init -backend-config=backend.hcl
#   terraform plan -var-file=terraform.tfvars
#   terraform apply -var-file=terraform.tfvars
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.20"
    }
  }

  backend "s3" {}
}

# ─── Provider Configuration ─────────────────────────────────────────────

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = var.common_tags
  }
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

# ─── Local Variables ─────────────────────────────────────────────────────

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ─── Module References ──────────────────────────────────────────────────
# In a real deployment, each cloud module is typically applied independently
# via CI/CD (see .github/workflows/medcloud-infra.yml).
# This root module documents the dependency order.
#
# APPLY ORDER:
#   1. terraform/{aws,azure,gcp}/networking   (VPCs, subnets, VPN)
#   2. terraform/{aws,azure,gcp}/security     (KMS, WAF, GuardDuty)
#   3. terraform/aws/eks, azure/aks, gcp/gke  (Kubernetes clusters)
#   4. terraform/{aws,azure,gcp}/databases    (Aurora, Cosmos, BigQuery)
#   5. terraform/{aws,azure,gcp}/storage      (S3, Blob, GCS)
#   6. terraform/azure/ai-services            (OpenAI, AI Vision)
#   7. terraform/gcp/analytics, gcp/ml-platform
#   8. terraform/aws/monitoring               (CloudWatch dashboards)
# ─────────────────────────────────────────────────────────────────────────

# ─── Additional Environment-Specific Variables ───────────────────────────

variable "project_name" {
  default = "medcloud"
}

variable "environment" {
  default = "dev"
}

variable "aws_region" {
  default = "us-east-1"
}

variable "azure_subscription_id" {
  description = "Azure Subscription ID"
  type        = string
  default     = ""
  sensitive   = true
}

variable "azure_location" {
  default = "eastus"
}

variable "gcp_project_id" {
  default = "medcloud-global-dev"
}

variable "gcp_region" {
  default = "us-central1"
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
