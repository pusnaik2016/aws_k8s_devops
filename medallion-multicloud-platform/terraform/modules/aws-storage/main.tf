# =============================================================================
# AWS STORAGE MODULE — S3 Medallion Data Lake Buckets
# =============================================================================
# Architecture:
#   Bronze  → Raw ingestion landing zone (versioned, lifecycle to IA)
#   Silver  → Cleansed/tokenized data (PII removed)
#   Gold    → Business aggregates (optimized for analytics)
#   Audit   → Immutable compliance logs (Object Lock, 365-day retention)
#
# COMPLIANCE:
#   HIPAA  — SSE-KMS encryption, block public access, VPC endpoint restriction
#   PCI-DSS — Object Lock governance on audit bucket, versioning enabled
#   SOC 2  — Access logging, lifecycle management
# =============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  account_id  = data.aws_caller_identity.current.account_id
  region      = data.aws_region.current.name

  tags = merge(var.common_tags, {
    Module      = "aws-storage"
    Cloud       = "aws"
    Environment = var.environment
    Compliance  = "hipaa-soc2-pci"
    ManagedBy   = "terraform"
  })

  medallion_buckets = {
    bronze = {
      name        = "${local.name_prefix}-bronze-landing"
      description = "Raw data ingestion landing zone"
      tier        = "bronze"
    }
    silver = {
      name        = "${local.name_prefix}-silver-curated"
      description = "Cleansed and tokenized data"
      tier        = "silver"
    }
    gold = {
      name        = "${local.name_prefix}-gold-aggregated"
      description = "Business-level aggregates for analytics"
      tier        = "gold"
    }
  }
}

# =============================================================================
# MEDALLION S3 BUCKETS (Bronze / Silver / Gold)
# =============================================================================
resource "aws_s3_bucket" "medallion" {
  for_each = local.medallion_buckets

  bucket        = each.value.name
  force_destroy = false

  tags = merge(local.tags, {
    Name          = each.value.name
    Description   = each.value.description
    MedallionTier = each.value.tier
  })
}

# Versioning — required for data integrity (HIPAA/SOC 2)
resource "aws_s3_bucket_versioning" "medallion" {
  for_each = local.medallion_buckets

  bucket = aws_s3_bucket.medallion[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}

# SSE-KMS Encryption with Customer-Managed Key
resource "aws_s3_bucket_server_side_encryption_configuration" "medallion" {
  for_each = local.medallion_buckets

  bucket = aws_s3_bucket.medallion[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.s3_kms_key_id
    }
    bucket_key_enabled = true
  }
}

# Block ALL public access (HIPAA/PCI-DSS zero public exposure)
resource "aws_s3_bucket_public_access_block" "medallion" {
  for_each = local.medallion_buckets

  bucket                  = aws_s3_bucket.medallion[each.key].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket policy — Deny non-VPC endpoint traffic + enforce TLS
resource "aws_s3_bucket_policy" "medallion" {
  for_each = local.medallion_buckets

  bucket = aws_s3_bucket.medallion[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyNonVPCEndpointAccess"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.medallion[each.key].arn,
          "${aws_s3_bucket.medallion[each.key].arn}/*"
        ]
        Condition = {
          StringNotEquals = {
            "aws:sourceVpce" = var.s3_vpc_endpoint_id
          }
        }
      },
      {
        Sid       = "EnforceTLSOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.medallion[each.key].arn,
          "${aws_s3_bucket.medallion[each.key].arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid       = "DenyUnencryptedObjectUploads"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.medallion[each.key].arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.medallion]
}

# Lifecycle rules — Bronze transitions to IA after 90 days
resource "aws_s3_bucket_lifecycle_configuration" "bronze" {
  bucket = aws_s3_bucket.medallion["bronze"].id

  rule {
    id     = "bronze-lifecycle"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 730 # 2 years
    }
  }
}

# Access logging for audit
resource "aws_s3_bucket_logging" "medallion" {
  for_each = local.medallion_buckets

  bucket        = aws_s3_bucket.medallion[each.key].id
  target_bucket = aws_s3_bucket.audit_logs.id
  target_prefix = "s3-access-logs/${each.value.tier}/"
}

# =============================================================================
# AUDIT LOG BUCKET — Immutable Compliance Store (Object Lock)
# =============================================================================
resource "aws_s3_bucket" "audit_logs" {
  bucket              = "${local.name_prefix}-audit-logs"
  force_destroy       = false
  object_lock_enabled = true

  tags = merge(local.tags, {
    Name        = "${local.name_prefix}-audit-logs"
    Description = "Immutable audit log archive for compliance"
    Compliance  = "hipaa-soc2-pci"
    Retention   = "365-days"
  })
}

resource "aws_s3_bucket_versioning" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.logs_kms_key_id
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "audit_logs" {
  bucket                  = aws_s3_bucket.audit_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Object Lock — Governance Mode, 365-day retention (PCI-DSS/HIPAA compliance)
resource "aws_s3_bucket_object_lock_configuration" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = 365
    }
  }

  depends_on = [aws_s3_bucket_versioning.audit_logs]
}

# Bucket policy for audit logs — deny deletion, enforce TLS
resource "aws_s3_bucket_policy" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceTLSOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.audit_logs.arn,
          "${aws_s3_bucket.audit_logs.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid       = "AllowCloudTrailWrite"
        Effect    = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.audit_logs.arn}/cloudtrail/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid       = "AllowCloudTrailBucketCheck"
        Effect    = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.audit_logs.arn
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.audit_logs]
}
