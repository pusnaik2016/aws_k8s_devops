# =============================================================================
# Remote State Module — S3 + DynamoDB for Terraform state locking
# Project: 3-Tier EKS Application
# Author: Pushparaj Naik
# =============================================================================

# --- S3 Bucket for Terraform State ---
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.prefix}-terraform-state"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "${var.prefix}-terraform-state"
    Environment = var.environment
    Purpose     = "Terraform Remote State"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- DynamoDB Table for State Locking ---
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  tags = {
    Name        = "terraform-state-lock"
    Environment = var.environment
    Purpose     = "Terraform State Locking"
  }
}
