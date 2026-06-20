# ============================================================================
# AWS Security — KMS, WAF, Shield, GuardDuty, Security Hub, CloudTrail
# ============================================================================

terraform {
  required_version = ">= 1.5"
}

data "aws_caller_identity" "current" {}

# ──────────────────────────────────────────────────────────────────────────────
# KMS Customer Managed Key (CMK) — HIPAA encryption
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_kms_key" "main" {
  description             = "HealthCloud CMK for ${var.environment} — PHI encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  multi_region            = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccountAccess"
        Effect = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowEKSUsage"
        Effect = "Allow"
        Principal = { Service = ["eks.amazonaws.com", "rds.amazonaws.com", "s3.amazonaws.com"] }
        Action = ["kms:Decrypt", "kms:DescribeKey", "kms:Encrypt", "kms:GenerateDataKey*", "kms:ReEncrypt*"]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name               = "${var.project}-${var.environment}-cmk"
    DataClassification = "phi"
    Compliance         = "hipaa"
  })
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.project}-${var.environment}-cmk"
  target_key_id = aws_kms_key.main.key_id
}

# ──────────────────────────────────────────────────────────────────────────────
# CloudTrail — Audit Logging (HIPAA requirement)
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_cloudtrail" "main" {
  name                          = "${var.project}-${var.environment}-trail"
  s3_bucket_name                = var.audit_bucket_name
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.main.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::${var.project}-${var.environment}-phi-data/"]
    }
  }

  insight_selector {
    insight_type = "ApiCallRateInsight"
  }

  tags = merge(var.common_tags, {
    Name       = "${var.project}-${var.environment}-trail"
    Compliance = "hipaa-audit"
  })
}

# ──────────────────────────────────────────────────────────────────────────────
# GuardDuty — Threat Detection
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_guardduty_detector" "main" {
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-guardduty"
  })
}

# ──────────────────────────────────────────────────────────────────────────────
# Security Hub — Compliance Dashboard
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_securityhub_account" "main" {}

resource "aws_securityhub_standards_subscription" "cis" {
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.4.0"
}

resource "aws_securityhub_standards_subscription" "aws_foundational" {
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/aws-foundational-security-best-practices/v/1.0.0"
}

# ──────────────────────────────────────────────────────────────────────────────
# WAF v2 — Web Application Firewall
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_wafv2_web_acl" "main" {
  name        = "${var.project}-${var.environment}-waf"
  scope       = "REGIONAL"
  description = "WAF for HealthCloud ${var.environment}"

  default_action {
    allow {}
  }

  rule {
    name     = "aws-managed-common-rules"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRules"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-managed-sql-injection"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLInjection"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "rate-limit"
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
      metric_name                = "RateLimit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "HealthCloudWAF"
    sampled_requests_enabled   = true
  }

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-waf"
  })
}

# ──────────────────────────────────────────────────────────────────────────────
# AWS Config — Compliance Rules
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_config_configuration_recorder" "main" {
  name     = "${var.project}-${var.environment}-config"
  role_arn = var.config_role_arn

  recording_group {
    all_supported = true
  }
}

resource "aws_config_config_rule" "encrypted_volumes" {
  name = "${var.project}-${var.environment}-encrypted-volumes"

  source {
    owner             = "AWS"
    source_identifier = "ENCRYPTED_VOLUMES"
  }

  depends_on = [aws_config_configuration_recorder.main]

  tags = merge(var.common_tags, {
    Compliance = "hipaa"
  })
}

resource "aws_config_config_rule" "s3_encryption" {
  name = "${var.project}-${var.environment}-s3-encryption"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder.main]

  tags = merge(var.common_tags, {
    Compliance = "hipaa"
  })
}
