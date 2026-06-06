# ==============================================================================
# Provider Configuration
# ==============================================================================
# Configures the AWS provider for Terraform. This file sets the required
# provider versions and specifies the target AWS region for all resources.
# For production use, uncomment the S3 backend block to enable remote state
# management with state locking via DynamoDB.
# ==============================================================================

terraform {
  # ---------------------------------------------------------------------------
  # Required Terraform version constraint
  # ---------------------------------------------------------------------------
  required_version = ">= 1.5.0"

  # ---------------------------------------------------------------------------
  # Required providers with version constraints
  # ---------------------------------------------------------------------------
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # ---------------------------------------------------------------------------
  # Backend Configuration (Local by default)
  # Uncomment the S3 backend below for production use with remote state
  # and state locking. Ensure the S3 bucket and DynamoDB table exist first.
  # ---------------------------------------------------------------------------
  # backend "s3" {
  #   bucket         = "devsecops-terraform-state"
  #   key            = "java-devsecops/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

# ==============================================================================
# AWS Provider
# ==============================================================================
# The AWS provider is configured using the region variable. AWS credentials
# should be provided via environment variables (AWS_ACCESS_KEY_ID and
# AWS_SECRET_ACCESS_KEY) or an IAM instance profile — never hardcoded.
# ==============================================================================
provider "aws" {
  region = var.aws_region

  # ---------------------------------------------------------------------------
  # Default tags applied to all AWS resources for cost tracking and management
  # ---------------------------------------------------------------------------
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "dev"
      ManagedBy   = "terraform"
      CreatedBy   = "devsecops-pipeline"
    }
  }
}
