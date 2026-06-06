# -----------------------------------------------------------------------------
# Storage Module — S3 Telemetry Archive + Amazon Timestream
# -----------------------------------------------------------------------------
# This module creates:
# 1. S3 Bucket — Raw telemetry archive with lifecycle policies
# 2. Amazon Timestream — Time-series database for real-time queries
# Both encrypted with KMS, aligned with Well-Architected Framework
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# S3 Bucket — Raw Telemetry Data Archive
# IoT Rules Engine writes raw MQTT messages here for long-term retention
# Lifecycle: Standard → IA (30d) → Glacier (90d) → Expire (7y)
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "telemetry" {
  bucket = "${var.project_name}-telemetry-${var.account_id}-${var.aws_region}"

  tags = {
    Name    = "${var.project_name}-telemetry"
    Purpose = "IoT telemetry raw data archive"
  }
}

resource "aws_s3_bucket_versioning" "telemetry" {
  bucket = aws_s3_bucket.telemetry.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "telemetry" {
  bucket = aws_s3_bucket.telemetry.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "telemetry" {
  bucket = aws_s3_bucket.telemetry.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "telemetry" {
  bucket = aws_s3_bucket.telemetry.id

  rule {
    id     = "TelemetryLifecycle"
    status = "Enabled"

    filter {
      prefix = "telemetry/"
    }

    transition {
      days          = var.s3_transition_ia_days
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = var.s3_transition_glacier_days
      storage_class = "GLACIER"
    }

    expiration {
      days = var.s3_expiration_days
    }
  }

  rule {
    id     = "ErrorLogRetention"
    status = "Enabled"

    filter {
      prefix = "errors/"
    }

    expiration {
      days = 90
    }
  }
}

resource "aws_s3_bucket_logging" "telemetry" {
  bucket        = aws_s3_bucket.telemetry.id
  target_bucket = aws_s3_bucket.telemetry.id
  target_prefix = "access-logs/"
}

# -----------------------------------------------------------------------------
# Amazon Timestream — Time-Series Database
# Optimized for IoT telemetry queries (avg, min, max, percentiles over time)
# Memory store = hot data (fast queries), Magnetic store = warm data
# -----------------------------------------------------------------------------
resource "aws_timestreamwrite_database" "telemetry" {
  database_name = "${replace(var.project_name, "-", "_")}_telemetry"
  kms_key_id    = var.kms_key_arn

  tags = {
    Name    = "${var.project_name}-timestream-db"
    Purpose = "IoT telemetry time-series storage"
  }
}

resource "aws_timestreamwrite_table" "sensor_data" {
  database_name = aws_timestreamwrite_database.telemetry.database_name
  table_name    = "sensor_data"

  retention_properties {
    memory_store_retention_period_in_hours  = var.timestream_memory_retention_hours
    magnetic_store_retention_period_in_days = var.timestream_magnetic_retention_days
  }

  magnetic_store_write_properties {
    enable_magnetic_store_writes = true
  }

  tags = {
    Name = "${var.project_name}-sensor-data-table"
  }
}
