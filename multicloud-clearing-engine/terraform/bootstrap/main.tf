# =============================================================================
# BOOTSTRAP — Terraform State Backends (All Clouds)
# =============================================================================
# Creates state storage infrastructure across AWS, Azure, and GCP.
# Each backend includes encryption, versioning, and access controls.
# =============================================================================

# Generate a unique suffix for globally unique names
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  bucket_name  = "${var.project_name}-tfstate-${random_string.suffix.result}"
  rg_name      = "${var.project_name}-terraform-state"
  sa_name      = replace("${var.project_name}tfstate", "-", "")
  gcs_name     = "${var.project_name}-tfstate-${random_string.suffix.result}"
}

# =============================================================================
# AWS — S3 Bucket + DynamoDB State Locking
# =============================================================================

resource "aws_s3_bucket" "tfstate" {
  bucket = local.bucket_name

  tags = {
    Name    = "Terraform State Backend"
    Purpose = "multicloud-state-management"
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    id     = "noncurrent-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

resource "aws_dynamodb_table" "tflock" {
  name         = "${var.project_name}-terraform-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name    = "Terraform State Lock"
    Purpose = "multicloud-state-locking"
  }
}

# =============================================================================
# AZURE — Storage Account + Blob Container
# =============================================================================

resource "azurerm_resource_group" "tfstate" {
  name     = local.rg_name
  location = var.azure_region

  tags = {
    Project   = var.project_name
    Component = "terraform-state"
    ManagedBy = "terraform-bootstrap"
  }
}

resource "azurerm_storage_account" "tfstate" {
  name                     = substr(local.sa_name, 0, 24)
  resource_group_name      = azurerm_resource_group.tfstate.name
  location                 = azurerm_resource_group.tfstate.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  min_tls_version          = "TLS1_2"

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }

  tags = {
    Project   = var.project_name
    Component = "terraform-state"
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.tfstate.name
  container_access_type = "private"
}

# =============================================================================
# GCP — GCS Bucket
# =============================================================================

resource "google_storage_bucket" "tfstate" {
  name     = local.gcs_name
  location = upper(var.gcp_region)

  versioning {
    enabled = true
  }

  uniform_bucket_level_access = true

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      num_newer_versions = 10
      with_state         = "ARCHIVED"
    }
  }

  labels = {
    project   = var.project_name
    component = "terraform-state"
    managed   = "bootstrap"
  }
}
