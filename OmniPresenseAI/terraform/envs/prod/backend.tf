# ─────────────────────────────────────────────────────────────
# Terraform Backend — S3 + DynamoDB State Locking
# ─────────────────────────────────────────────────────────────

terraform {
  backend "s3" {
    bucket         = "omnipresense-ai-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "omnipresense-ai-terraform-locks"
    encrypt        = true
  }
}
