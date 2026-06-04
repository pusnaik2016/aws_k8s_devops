# ─────────────────────────────────────────────────────────────
# Provider Configuration — Production
# ─────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "omnipresense-ai"
      Environment = "prod"
      ManagedBy   = "terraform"
      Owner       = "pushparaj-naik"
    }
  }
}
