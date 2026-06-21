# ─────────────────────────────────────────────────────────────────────────────
# Security Module — Compliance Stack (PCI-DSS, SOC2, HIPAA, GDPR)
# ─────────────────────────────────────────────────────────────────────────────
# Controls:
# - KMS keys with auto-rotation (PCI-DSS 3.5, HIPAA §164.312(a)(2)(iv))
# - GuardDuty threat detection (SOC2 CC6.8)
# - Security Hub compliance standards (PCI-DSS, CIS, AWS Foundational)
# - CloudTrail with log file validation (SOC2 CC7.2, HIPAA audit)
# - WAF v2 on ALB (PCI-DSS 6.6, OWASP Top 10)
# - Config Rules for continuous compliance
# ─────────────────────────────────────────────────────────────────────────────

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# ─── KMS Keys ────────────────────────────────────────────────────────────────

# General purpose encryption key (EBS, S3, RDS, CloudWatch)
resource "aws_kms_key" "general" {
  description             = "General purpose encryption key for ${var.name_prefix}"
  deletion_window_in_days = 30
  enable_key_rotation     = true # PCI-DSS 3.5: Automatic key rotation

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow RDS"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name       = "${var.name_prefix}-general-kms"
    Compliance = "PCI-DSS,HIPAA"
  })
}

resource "aws_kms_alias" "general" {
  name          = "alias/${var.name_prefix}-general"
  target_key_id = aws_kms_key.general.key_id
}

# ─── CloudTrail (Audit Logging) ─────────────────────────────────────────────

resource "aws_s3_bucket" "cloudtrail" {
  bucket        = "${var.name_prefix}-cloudtrail-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.environment != "prod"

  tags = merge(var.common_tags, {
    Name       = "${var.name_prefix}-cloudtrail"
    Compliance = "SOC2,HIPAA,PCI-DSS"
  })
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.general.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket                  = aws_s3_bucket.cloudtrail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    id     = "archive-old-logs"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = var.log_retention_days
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid       = "DenyUnencryptedTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.cloudtrail.arn,
          "${aws_s3_bucket.cloudtrail.arn}/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      }
    ]
  })
}

resource "aws_cloudtrail" "main" {
  name                          = "${var.name_prefix}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true # SOC2: tamper-evident audit logs
  kms_key_id                    = aws_kms_key.general.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:${data.aws_partition.current.partition}:s3:::"]
    }
  }

  tags = merge(var.common_tags, {
    Name       = "${var.name_prefix}-cloudtrail"
    Compliance = "SOC2,HIPAA,PCI-DSS,GDPR"
  })

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}

# ─── GuardDuty (Threat Detection) ───────────────────────────────────────────

resource "aws_guardduty_detector" "main" {
  count  = var.enable_guardduty ? 1 : 0
  enable = true

  datasources {
    kubernetes {
      audit_logs {
        enable = true # Monitor EKS audit logs for threats
      }
    }
    s3_logs {
      enable = true
    }
  }

  tags = merge(var.common_tags, {
    Name       = "${var.name_prefix}-guardduty"
    Compliance = "SOC2,HIPAA"
  })
}

# ─── Security Hub (Compliance Dashboard) ────────────────────────────────────

resource "aws_securityhub_account" "main" {
  count                    = var.enable_security_hub ? 1 : 0
  enable_default_standards = false
  auto_enable_controls     = true
}

resource "aws_securityhub_standards_subscription" "pci_dss" {
  count         = var.enable_security_hub ? 1 : 0
  standards_arn = "arn:${data.aws_partition.current.partition}:securityhub:${var.aws_region}::standards/pci-dss/v/3.2.1"
  depends_on    = [aws_securityhub_account.main]
}

resource "aws_securityhub_standards_subscription" "cis" {
  count         = var.enable_security_hub ? 1 : 0
  standards_arn = "arn:${data.aws_partition.current.partition}:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.4.0"
  depends_on    = [aws_securityhub_account.main]
}

resource "aws_securityhub_standards_subscription" "aws_foundational" {
  count         = var.enable_security_hub ? 1 : 0
  standards_arn = "arn:${data.aws_partition.current.partition}:securityhub:${var.aws_region}::standards/aws-foundational-security-best-practices/v/1.0.0"
  depends_on    = [aws_securityhub_account.main]
}

# ─── WAF v2 (Web Application Firewall) ──────────────────────────────────────

resource "aws_wafv2_web_acl" "main" {
  count       = var.enable_waf ? 1 : 0
  name        = "${var.name_prefix}-waf"
  description = "WAF for EKS Retail Platform ALB"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # OWASP: SQL Injection protection
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 1
    override_action { none {} }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-sqli"
      sampled_requests_enabled   = true
    }
  }

  # OWASP: Common rule set (XSS, LFI, etc.)
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 2
    override_action { none {} }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-common"
      sampled_requests_enabled   = true
    }
  }

  # Rate limiting (DDoS layer 7 protection)
  rule {
    name     = "RateLimit"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  # Known bad inputs
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 4
    override_action { none {} }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name_prefix}-waf"
    sampled_requests_enabled   = true
  }

  tags = merge(var.common_tags, {
    Name       = "${var.name_prefix}-waf"
    Compliance = "PCI-DSS"
  })
}

# ─── ECR Repositories (with image scanning) ─────────────────────────────────

locals {
  ecr_repositories = [
    "storefront-api",
    "order-service",
    "inventory-service",
    "payment-service",
    "notification-service"
  ]
}

resource "aws_ecr_repository" "services" {
  for_each = toset(local.ecr_repositories)

  name                 = "${var.name_prefix}/${each.key}"
  image_tag_mutability = "IMMUTABLE" # PCI-DSS: prevent tag overwriting

  image_scanning_configuration {
    scan_on_push = true # Scan every image on push
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.general.arn
  }

  tags = merge(var.common_tags, {
    Name       = "${var.name_prefix}-${each.key}"
    Compliance = "PCI-DSS,SOC2"
  })
}

resource "aws_ecr_lifecycle_policy" "services" {
  for_each   = toset(local.ecr_repositories)
  repository = aws_ecr_repository.services[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 30 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
