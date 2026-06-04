# =============================================================================
# MULTICLOUD PROVIDER CONFIGURATION
# Global Healthcare & Financial Transaction Clearing Engine
# =============================================================================
# This file configures Terraform providers for AWS (Primary), Azure (Hot
# Standby), and GCP (Compliance & Analytics). State is stored in S3 with
# DynamoDB locking for team-safe operations.
# =============================================================================

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket         = "enterprise-global-tfstate"
    key            = "multicloud/prod.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}

# -----------------------------------------------------------------------------
# AWS Provider — Primary Active Site (us-east-1)
# -----------------------------------------------------------------------------
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Compliance  = "hipaa-sox-gdpr"
    }
  }
}

# Secondary AWS provider for CloudFront ACM certificates (must be us-east-1)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# -----------------------------------------------------------------------------
# Azure Provider — Hot Standby Site
# -----------------------------------------------------------------------------
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }

  # Subscription is sourced from ARM_SUBSCRIPTION_ID env var or variables
  subscription_id = var.azure_subscription_id
}

# Azure AD Provider — Centralized Identity & User Management
provider "azuread" {
  tenant_id = var.azure_tenant_id
}

# -----------------------------------------------------------------------------
# GCP Provider — Compliance & Analytics Layer
# -----------------------------------------------------------------------------
provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}
