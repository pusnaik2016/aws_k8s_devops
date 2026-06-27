# ==============================================================================
# AWS CloudTrail — API Audit Logging
# ==============================================================================
# Compliance requirements addressed:
#   PCI DSS Req 10  : Audit all access to network resources and cardholder data
#   PCI DSS Req 10.3: Protect audit logs from modification (log file validation)
#   PCI DSS Req 10.5: Retain logs for at least 12 months (7yr here via Glacier)
#   HIPAA §164.312  : Audit controls — hardware, software, procedural mechanisms
#   SOC 2 CC7.2     : Monitor system components for anomalies and events
#
# What is captured:
#   - All AWS management API calls (IAM, EKS, ECR, S3, Cognito, WAF, etc.)
#   - S3 data-level events (object read/write)
#   - Global service events (IAM, STS — cross-region)
#   - Multi-region trail ensures no region is a blind spot
# ==============================================================================

data "aws_caller_identity" "current" {}

# =============================================================================
# S3 Bucket — Immutable audit log storage
# =============================================================================
resource "aws_s3_bucket" "audit_logs" {
  bucket        = "${var.project_name}-audit-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = false # never auto-delete audit logs — PCI Req 10.5

  tags = {
    Name       = "${var.project_name}-audit-logs"
    Compliance = "PCI-HIPAA-SOC2"
  }
}

# Block all public access — audit logs must never be public
resource "aws_s3_bucket_public_access_block" "audit_logs" {
  bucket                  = aws_s3_bucket.audit_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning — detect and recover from accidental deletion (SOC 2 CC9)
resource "aws_s3_bucket_versioning" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# KMS encryption at rest — HIPAA + PCI Req 3
resource "aws_s3_bucket_server_side_encryption_configuration" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.eks.arn
    }
    bucket_key_enabled = true # reduces KMS API costs
  }
}

# Lifecycle — 90 days S3 Standard → Glacier → expire at 7 years
# PCI requires 1yr accessible + 3yr archive; HIPAA requires 6yr; 7yr covers all
resource "aws_s3_bucket_lifecycle_configuration" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  rule {
    id     = "compliance-retention"
    status = "Enabled"

    filter {}

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 2555 # 7 years
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# Bucket policy — allow CloudTrail to write, deny non-TLS access
resource "aws_s3_bucket_policy" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.audit_logs.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.audit_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        # Deny any non-TLS access — PCI Req 4 (encrypt data in transit)
        Sid       = "DenyNonTLS"
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
      }
    ]
  })
}

# =============================================================================
# CloudTrail — Multi-region trail with log file validation
# =============================================================================
resource "aws_cloudtrail" "main" {
  name                          = "${var.project_name}-trail"
  s3_bucket_name                = aws_s3_bucket.audit_logs.id
  include_global_service_events = true # captures IAM, STS (cross-region)
  is_multi_region_trail         = true # no region is a blind spot
  enable_log_file_validation    = true # SHA-256 digest — PCI Req 10.3 tamper detection
  kms_key_id                    = aws_kms_key.eks.arn

  # Capture S3 data-level events (object reads and writes)
  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::"] # all buckets
    }
  }

  depends_on = [
    aws_s3_bucket_policy.audit_logs
  ]

  tags = {
    Name       = "${var.project_name}-trail"
    Compliance = "PCI-HIPAA-SOC2"
  }
}
