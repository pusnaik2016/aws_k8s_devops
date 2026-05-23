###############################################################################
# Bedrock Config Module — Terraform version + provider constraints
###############################################################################

terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}
