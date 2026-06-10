# ─────────────────────────────────────────────────────────────────────────────
# MedCloud Global Platform — Root Terraform Configuration
# ─────────────────────────────────────────────────────────────────────────────
# This is the root orchestrator that calls cloud-specific modules.
# Each cloud provider has its own state file for blast radius isolation.
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
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}
