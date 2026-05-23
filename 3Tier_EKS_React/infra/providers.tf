# =============================================================================
# Terraform Provider Configuration
# Project: 3-Tier EKS Application
# Author: Pushparaj Naik
# Compliance: AWS Well-Architected Framework, GDPR, SOC2
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Remote state management (S3 + DynamoDB locking)
  # IMPORTANT: First deploy the bootstrap resources via module "state", then uncomment:
  # backend "s3" {
  #   bucket         = "pushparaj-terraform-state"
  #   key            = "3tier-eks/terraform.tfstate"
  #   region         = "ap-south-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

# --- Primary Region ---
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "Pushparaj Naik"
      Compliance  = "GDPR-SOC2"
    }
  }
}

# --- DR Region (cross-region backups) ---
provider "aws" {
  alias  = "dr_region"
  region = var.dr_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "${var.environment}-dr"
      ManagedBy   = "Terraform"
      Owner       = "Pushparaj Naik"
      Compliance  = "GDPR-SOC2"
    }
  }
}

# --- Helm Provider (authenticates to EKS) ---
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

# --- Kubernetes Provider (namespace/manifest management) ---
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}
