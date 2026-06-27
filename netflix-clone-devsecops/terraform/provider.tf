# ==============================================================================
# Provider Configuration — Netflix Clone DevSecOps
# ==============================================================================
terraform {
  required_version = ">= 1.5.0"

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
  # Uncomment the S3 backend below for production use with remote state.
  # ---------------------------------------------------------------------------
  # backend "s3" {
  #   bucket         = "netflix-devsecops-terraform-state"
  #   key            = "netflix-devsecops/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "dev"
      ManagedBy   = "terraform"
      CreatedBy   = "devsecops-pipeline"
    }
  }
}
