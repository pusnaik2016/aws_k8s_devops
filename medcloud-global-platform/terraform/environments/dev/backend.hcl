# ─────────────────────────────────────────────────────────────────────────────
# Dev Environment — Backend Configuration
# ─────────────────────────────────────────────────────────────────────────────
# Usage: terraform init -backend-config=backend.hcl
# ─────────────────────────────────────────────────────────────────────────────

# AWS State Backend
bucket         = "medcloud-terraform-state-dev"
key            = "dev/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "medcloud-terraform-locks-dev"
