# ============================================================================
# AWS Storage — S3 (HIPAA: SSE-KMS, Object Lock, Versioning) + CloudFront
# ============================================================================

terraform {
  required_version = ">= 1.5"
}

# ──────────────────────────────────────────────────────────────────────────────
# S3 Bucket — PHI Data (medical images, documents)
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "phi_data" {
  bucket = "${var.project}-${var.environment}-phi-data-${var.aws_account_id}"

  tags = merge(var.common_tags, {
    Name               = "${var.project}-${var.environment}-phi-data"
    DataClassification = "phi"
    Compliance         = "hipaa"
  })
}

resource "aws_s3_bucket_versioning" "phi_data" {
  bucket = aws_s3_bucket.phi_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "phi_data" {
  bucket = aws_s3_bucket.phi_data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "phi_data" {
  bucket                  = aws_s3_bucket.phi_data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "phi_data" {
  bucket = aws_s3_bucket.phi_data.id

  rule {
    id     = "archive-old-data"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }

    # HIPAA: 7-year retention
    noncurrent_version_expiration {
      noncurrent_days = 2555  # ~7 years
    }
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# S3 Bucket — Audit Logs (immutable, Object Lock WORM)
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "audit_logs" {
  bucket              = "${var.project}-${var.environment}-audit-logs-${var.aws_account_id}"
  object_lock_enabled = true

  tags = merge(var.common_tags, {
    Name               = "${var.project}-${var.environment}-audit-logs"
    DataClassification = "audit"
    Compliance         = "hipaa-audit"
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
      kms_master_key_id = var.kms_key_arn
    }
  }
}

resource "aws_s3_bucket_object_lock_configuration" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = 2555  # 7 years — HIPAA requirement
    }
  }
}

resource "aws_s3_bucket_public_access_block" "audit_logs" {
  bucket                  = aws_s3_bucket.audit_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ──────────────────────────────────────────────────────────────────────────────
# CloudFront Distribution (static assets only — no PHI via CDN)
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "static_assets" {
  bucket = "${var.project}-${var.environment}-static-assets-${var.aws_account_id}"

  tags = merge(var.common_tags, {
    Name               = "${var.project}-${var.environment}-static-assets"
    DataClassification = "public"
  })
}

resource "aws_s3_bucket_public_access_block" "static_assets" {
  bucket                  = aws_s3_bucket.static_assets.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  web_acl_id          = var.waf_acl_arn

  origin {
    domain_name              = aws_s3_bucket.static_assets.bucket_regional_domain_name
    origin_id                = "s3-static-assets"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-static-assets"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = var.allowed_countries
    }
  }

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-cdn"
  })
}

resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "${var.project}-${var.environment}-s3-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
