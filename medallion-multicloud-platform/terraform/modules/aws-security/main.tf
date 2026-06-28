# =============================================================================
# AWS SECURITY MODULE — KMS, Secrets Manager, IAM, CloudTrail
# =============================================================================
# COMPLIANCE:
#   HIPAA  — All data encrypted at rest with CMK, CloudTrail for audit
#   SOC 2  — No long-lived static credentials, OIDC federation for CI/CD
#   PCI-DSS — Blast-radius isolation per encryption domain, automated rotation
# =============================================================================

# ---------------------------------------------------------------------------
# Data Sources
# ---------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  account_id  = data.aws_caller_identity.current.account_id
  region      = data.aws_region.current.name

  tags = merge(var.common_tags, {
    Module      = "aws-security"
    Cloud       = "aws"
    Environment = var.environment
    Compliance  = "hipaa-soc2-pci"
    ManagedBy   = "terraform"
  })
}

# =============================================================================
# KMS CUSTOMER-MANAGED KEYS — Blast-Radius Isolation
# =============================================================================

# -----------------------------------------------------------------------------
# S3 Medallion Data CMK (Bronze / Silver / Gold buckets)
# -----------------------------------------------------------------------------
resource "aws_kms_key" "s3_data" {
  description             = "CMK for S3 medallion data encryption — ${local.name_prefix}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  multi_region            = false

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "${local.name_prefix}-s3-data-key-policy"
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
        Sid    = "AllowS3Service"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
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
        Sid    = "AllowDatabricksCrossAccountRole"
        Effect = "Allow"
        Principal = {
          AWS = var.databricks_cross_account_role_arn
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.tags, {
    Name           = "${local.name_prefix}-kms-s3-data"
    EncryptionZone = "medallion-data"
  })
}

resource "aws_kms_alias" "s3_data" {
  name          = "alias/${local.name_prefix}-s3-data"
  target_key_id = aws_kms_key.s3_data.key_id
}

# -----------------------------------------------------------------------------
# Databricks Managed Services CMK (DBFS, notebooks, workspace)
# -----------------------------------------------------------------------------
resource "aws_kms_key" "databricks" {
  description             = "CMK for Databricks managed services — ${local.name_prefix}"
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
        Sid    = "AllowDatabricksControlPlane"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::414351767826:root" # Databricks control plane account
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant"
        ]
        Resource = "*"
        Condition = {
          Bool = {
            "kms:GrantIsForAWSResource" = "true"
          }
        }
      }
    ]
  })

  tags = merge(local.tags, {
    Name           = "${local.name_prefix}-kms-databricks"
    EncryptionZone = "databricks-managed"
  })
}

resource "aws_kms_alias" "databricks" {
  name          = "alias/${local.name_prefix}-databricks"
  target_key_id = aws_kms_key.databricks.key_id
}

# -----------------------------------------------------------------------------
# Logs & Audit Trail CMK (CloudWatch, CloudTrail)
# -----------------------------------------------------------------------------
resource "aws_kms_key" "logs" {
  description             = "CMK for CloudWatch/CloudTrail log encryption — ${local.name_prefix}"
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
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${local.region}.amazonaws.com"
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
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${local.region}:${local.account_id}:*"
          }
        }
      },
      {
        Sid    = "AllowCloudTrailEncrypt"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:SourceArn" = "arn:aws:cloudtrail:${local.region}:${local.account_id}:trail/${local.name_prefix}-audit-trail"
          }
        }
      }
    ]
  })

  tags = merge(local.tags, {
    Name           = "${local.name_prefix}-kms-logs"
    EncryptionZone = "audit-logs"
  })
}

resource "aws_kms_alias" "logs" {
  name          = "alias/${local.name_prefix}-logs"
  target_key_id = aws_kms_key.logs.key_id
}

# =============================================================================
# AWS SECRETS MANAGER — Runtime Credential Store
# =============================================================================

# Databricks Personal Access Token (rotated every 90 days)
resource "aws_secretsmanager_secret" "databricks_token" {
  name        = "${local.name_prefix}/databricks/access-token"
  description = "Databricks workspace personal access token"
  kms_key_id  = aws_kms_key.s3_data.arn

  tags = merge(local.tags, {
    SecretType   = "databricks-pat"
    RotationDays = "90"
  })
}

# Redshift / Data Warehouse Credentials
resource "aws_secretsmanager_secret" "warehouse_credentials" {
  name        = "${local.name_prefix}/warehouse/credentials"
  description = "Data warehouse connection credentials"
  kms_key_id  = aws_kms_key.s3_data.arn

  tags = merge(local.tags, {
    SecretType   = "warehouse-creds"
    RotationDays = "90"
  })
}

# PII Tokenization Encryption Key
resource "aws_secretsmanager_secret" "tokenization_key" {
  name        = "${local.name_prefix}/encryption/tokenization-key"
  description = "Format-preserving encryption key for PII/PAN tokenization"
  kms_key_id  = aws_kms_key.s3_data.arn

  tags = merge(local.tags, {
    SecretType = "encryption-key"
    Compliance = "pci-dss-hipaa"
  })
}

# Storage Account Keys (for cross-cloud DR replication)
resource "aws_secretsmanager_secret" "azure_storage_key" {
  name        = "${local.name_prefix}/azure/storage-key"
  description = "Azure DR ADLS Gen2 storage access key"
  kms_key_id  = aws_kms_key.s3_data.arn

  tags = merge(local.tags, {
    SecretType   = "azure-storage"
    RotationDays = "90"
  })
}

# =============================================================================
# IAM — Databricks Cross-Account Role
# =============================================================================
resource "aws_iam_role" "databricks_cross_account" {
  name = "${local.name_prefix}-databricks-cross-account"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::414351767826:root" # Databricks control plane
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "sts:ExternalId" = var.databricks_account_id
        }
      }
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "databricks_cross_account" {
  name = "${local.name_prefix}-databricks-cross-account-policy"
  role = aws_iam_role.databricks_cross_account.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2ForDatabricks"
        Effect = "Allow"
        Action = [
          "ec2:AllocateAddress",
          "ec2:AssignPrivateIpAddresses",
          "ec2:AssociateRouteTable",
          "ec2:AttachInternetGateway",
          "ec2:AttachVolume",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:CreateVolume",
          "ec2:DeleteVolume",
          "ec2:Describe*",
          "ec2:DetachVolume",
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3AccessForDBFS"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::${local.name_prefix}-*",
          "arn:aws:s3:::${local.name_prefix}-*/*"
        ]
      }
    ]
  })
}

# =============================================================================
# IAM — GitHub Actions OIDC Federation (SOC 2: No static secrets in CI/CD)
# =============================================================================
data "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = local.tags
}

locals {
  github_oidc_provider_arn = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

resource "aws_iam_role" "github_deployer" {
  name = "${local.name_prefix}-GitHubDABDeployer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = local.github_oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"
        }
      }
    }]
  })

  tags = merge(local.tags, {
    Purpose = "github-actions-oidc-deployer"
  })
}

resource "aws_iam_role_policy" "github_deployer" {
  name = "${local.name_prefix}-github-deployer-policy"
  role = aws_iam_role.github_deployer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DatabricksBundleDeploy"
        Effect = "Allow"
        Action = [
          "databricks:*",
          "sts:AssumeRole",
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      },
      {
        Sid    = "SecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:${local.name_prefix}/*"
      },
      {
        Sid    = "KMSDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = [
          aws_kms_key.s3_data.arn,
          aws_kms_key.databricks.arn
        ]
      }
    ]
  })
}

# =============================================================================
# CLOUDTRAIL — Immutable Audit Trail (HIPAA/SOC 2/PCI-DSS)
# =============================================================================
resource "aws_cloudtrail" "audit" {
  name                          = "${local.name_prefix}-audit-trail"
  s3_bucket_name                = var.audit_log_bucket_name
  s3_key_prefix                 = "cloudtrail"
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true
  kms_key_id                    = aws_kms_key.logs.arn

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cw.arn

  # Data events for S3 (audit every read/write on medallion buckets)
  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::${local.name_prefix}-bronze-landing/",
                "arn:aws:s3:::${local.name_prefix}-silver-curated/",
                "arn:aws:s3:::${local.name_prefix}-gold-aggregated/"]
    }
  }

  tags = merge(local.tags, {
    Name       = "${local.name_prefix}-audit-trail"
    Compliance = "hipaa-soc2-pci"
  })
}

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${local.name_prefix}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.logs.arn

  tags = local.tags
}

resource "aws_iam_role" "cloudtrail_cw" {
  name = "${local.name_prefix}-cloudtrail-cw-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "cloudtrail.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "cloudtrail_cw" {
  name = "${local.name_prefix}-cloudtrail-cw-policy"
  role = aws_iam_role.cloudtrail_cw.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
    }]
  })
}

# =============================================================================
# AWS CONFIG — Compliance Validation Rules
# =============================================================================
resource "aws_config_config_rule" "s3_encryption" {
  name = "${local.name_prefix}-s3-encryption-check"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }

  tags = merge(local.tags, {
    Compliance = "pci-dss-3.4"
  })
}

resource "aws_config_config_rule" "s3_public_access" {
  name = "${local.name_prefix}-s3-no-public-access"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }

  tags = merge(local.tags, {
    Compliance = "hipaa-164.312"
  })
}

resource "aws_config_config_rule" "encrypted_volumes" {
  name = "${local.name_prefix}-encrypted-volumes"

  source {
    owner             = "AWS"
    source_identifier = "ENCRYPTED_VOLUMES"
  }

  tags = merge(local.tags, {
    Compliance = "pci-dss-3.4"
  })
}

resource "aws_config_config_rule" "cloudtrail_enabled" {
  name = "${local.name_prefix}-cloudtrail-enabled"

  source {
    owner             = "AWS"
    source_identifier = "CLOUD_TRAIL_ENABLED"
  }

  tags = merge(local.tags, {
    Compliance = "soc2-cc6.1"
  })
}

resource "aws_config_config_rule" "iam_root_mfa" {
  name = "${local.name_prefix}-root-mfa-enabled"

  source {
    owner             = "AWS"
    source_identifier = "ROOT_ACCOUNT_MFA_ENABLED"
  }

  tags = merge(local.tags, {
    Compliance = "pci-dss-8.3"
  })
}
