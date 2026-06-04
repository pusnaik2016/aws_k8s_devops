# =============================================================================
# AWS KMS — Customer-Managed Encryption Keys
# =============================================================================
# HIPAA/SOX: All data at rest encrypted with CMK
# Key rotation enabled (annual automatic rotation)
# Separate keys per service for blast-radius isolation
# =============================================================================

# -----------------------------------------------------------------------------
# Primary KMS Key (EKS, CloudWatch, S3, General)
# -----------------------------------------------------------------------------
resource "aws_kms_key" "main" {
  description             = "Primary CMK for ${local.name_prefix} — encrypts EKS secrets, CW logs, S3"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  multi_region            = false

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "${local.name_prefix}-key-policy"
    Statement = [
      {
        Sid    = "EnableRootAccountFullAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.region}:${local.account_id}:*"
          }
        }
      },
      {
        Sid    = "AllowEKSEncryption"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
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

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-kms-primary"
  })
}

resource "aws_kms_alias" "main" {
  name          = "alias/${local.name_prefix}-primary"
  target_key_id = aws_kms_key.main.key_id
}

# -----------------------------------------------------------------------------
# RDS KMS Key (Aurora-specific for compliance isolation)
# -----------------------------------------------------------------------------
resource "aws_kms_key" "rds" {
  description             = "CMK for Aurora PostgreSQL encryption — ${local.name_prefix}"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccountFullAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowRDSService"
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

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-kms-rds"
  })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${local.name_prefix}-rds"
  target_key_id = aws_kms_key.rds.key_id
}
