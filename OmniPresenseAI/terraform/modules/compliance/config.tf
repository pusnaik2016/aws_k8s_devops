# ─────────────────────────────────────────────────────────────
# AWS Config — Configuration Compliance
# ─────────────────────────────────────────────────────────────
# Compliance: HIPAA, PCI-DSS, CIS, SOX
# WAF Pillar: Security, Operational Excellence
# Tracks configuration changes and evaluates compliance rules
# ─────────────────────────────────────────────────────────────

resource "aws_config_configuration_recorder" "main" {
  name     = "${var.project_name}-${var.environment}-config-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "main" {
  name           = "${var.project_name}-${var.environment}-config-channel"
  s3_bucket_name = aws_s3_bucket.config.id

  snapshot_delivery_properties {
    delivery_frequency = "TwentyFour_Hours"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.main]
}

# S3 bucket for Config snapshots
resource "aws_s3_bucket" "config" {
  bucket        = "${var.project_name}-${var.environment}-config-logs"
  force_destroy = var.environment != "prod"

  tags = merge(var.tags, { Compliance = "HIPAA,PCI-DSS,SOX" })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  bucket = aws_s3_bucket.config.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_s3_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "config" {
  bucket                  = aws_s3_bucket.config.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "config" {
  bucket = aws_s3_bucket.config.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSConfigBucketPermissionsCheck"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.config.arn
      },
      {
        Sid       = "AWSConfigBucketDelivery"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.config.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"
        Condition = {
          StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
        }
      }
    ]
  })
}

# IAM Role for Config
resource "aws_iam_role" "config" {
  name = "${var.project_name}-${var.environment}-config-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_iam_role_policy" "config_s3" {
  name = "config-s3-delivery"
  role = aws_iam_role.config.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject", "s3:GetBucketAcl"]
      Resource = [aws_s3_bucket.config.arn, "${aws_s3_bucket.config.arn}/*"]
    }]
  })
}

# ─── AWS Config Rules (Compliance Checks) ────────────────────

# HIPAA: Encryption at rest required
resource "aws_config_config_rule" "s3_encryption" {
  name = "${var.project_name}-s3-bucket-encryption"
  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }
  depends_on = [aws_config_configuration_recorder.main]
}

# HIPAA + PCI-DSS: No public S3 buckets
resource "aws_config_config_rule" "s3_public_read" {
  name = "${var.project_name}-s3-no-public-read"
  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }
  depends_on = [aws_config_configuration_recorder.main]
}

# PCI-DSS: RDS encryption at rest
resource "aws_config_config_rule" "rds_encryption" {
  name = "${var.project_name}-rds-encryption"
  source {
    owner             = "AWS"
    source_identifier = "RDS_STORAGE_ENCRYPTED"
  }
  depends_on = [aws_config_configuration_recorder.main]
}

# PCI-DSS 10: CloudTrail enabled
resource "aws_config_config_rule" "cloudtrail_enabled" {
  name = "${var.project_name}-cloudtrail-enabled"
  source {
    owner             = "AWS"
    source_identifier = "CLOUD_TRAIL_ENABLED"
  }
  depends_on = [aws_config_configuration_recorder.main]
}

# SOX: IAM root access key check
resource "aws_config_config_rule" "iam_root_access_key" {
  name = "${var.project_name}-iam-root-access-key"
  source {
    owner             = "AWS"
    source_identifier = "IAM_ROOT_ACCESS_KEY_CHECK"
  }
  depends_on = [aws_config_configuration_recorder.main]
}

# HIPAA: EKS secrets encrypted
resource "aws_config_config_rule" "eks_secrets_encrypted" {
  name = "${var.project_name}-eks-secrets-encrypted"
  source {
    owner             = "AWS"
    source_identifier = "EKS_SECRETS_ENCRYPTED"
  }
  depends_on = [aws_config_configuration_recorder.main]
}

# PCI-DSS: KMS key rotation
resource "aws_config_config_rule" "kms_rotation" {
  name = "${var.project_name}-kms-key-rotation"
  source {
    owner             = "AWS"
    source_identifier = "CMK_BACKING_KEY_ROTATION_ENABLED"
  }
  depends_on = [aws_config_configuration_recorder.main]
}

# HIPAA: VPC flow logs enabled
resource "aws_config_config_rule" "vpc_flow_logs" {
  name = "${var.project_name}-vpc-flow-logs"
  source {
    owner             = "AWS"
    source_identifier = "VPC_FLOW_LOGS_ENABLED"
  }
  depends_on = [aws_config_configuration_recorder.main]
}

# HIPAA: Encrypted in transit (Redis, RDS)
resource "aws_config_config_rule" "elasticache_transit_encryption" {
  name = "${var.project_name}-elasticache-transit-encryption"
  source {
    owner             = "AWS"
    source_identifier = "ELASTICACHE_REPL_GRP_ENCRYPTED_IN_TRANSIT"
  }
  depends_on = [aws_config_configuration_recorder.main]
}

# GDPR: S3 bucket versioning (data integrity)
resource "aws_config_config_rule" "s3_versioning" {
  name = "${var.project_name}-s3-versioning"
  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_VERSIONING_ENABLED"
  }
  depends_on = [aws_config_configuration_recorder.main]
}
