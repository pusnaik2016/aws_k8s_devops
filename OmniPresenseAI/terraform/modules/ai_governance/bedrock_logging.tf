# ─────────────────────────────────────────────────────────────
# Amazon Bedrock — Model Invocation Logging
# ─────────────────────────────────────────────────────────────
# AI Lens: Observability, audit trail, cost tracking
# Compliance: SOX (audit trail), HIPAA (access logging)
# Logs all model invocations to CloudWatch + S3
# ─────────────────────────────────────────────────────────────

# S3 bucket for Bedrock invocation logs (long-term archive)
resource "aws_s3_bucket" "bedrock_logs" {
  bucket        = "${var.project_name}-${var.environment}-bedrock-logs"
  force_destroy = var.environment != "prod"

  tags = merge(var.tags, {
    Name       = "${var.project_name}-${var.environment}-bedrock-logs"
    AILens     = "Observability"
    Compliance = "SOX,HIPAA"
  })
}

resource "aws_s3_bucket_versioning" "bedrock_logs" {
  bucket = aws_s3_bucket.bedrock_logs.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bedrock_logs" {
  bucket = aws_s3_bucket.bedrock_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_s3_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "bedrock_logs" {
  bucket                  = aws_s3_bucket.bedrock_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "bedrock_logs" {
  bucket = aws_s3_bucket.bedrock_logs.id
  rule {
    id     = "archive-bedrock-logs"
    status = "Enabled"
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    expiration {
      days = 2555 # ~7 years
    }
  }
}

# CloudWatch Log Group for real-time Bedrock invocation logs
resource "aws_cloudwatch_log_group" "bedrock" {
  name              = "/aws/bedrock/${var.project_name}-${var.environment}/model-invocations"
  retention_in_days = 90
  kms_key_id        = var.kms_s3_key_arn

  tags = merge(var.tags, {
    AILens     = "Observability"
    Compliance = "SOX"
  })
}

# Bedrock Model Invocation Logging Configuration
resource "aws_bedrock_model_invocation_logging_configuration" "main" {
  logging_config {
    embedding_data_delivery_enabled = true

    # CloudWatch — real-time monitoring
    cloudwatch_config {
      log_group_name = aws_cloudwatch_log_group.bedrock.name
      role_arn       = aws_iam_role.bedrock_logging.arn

      large_data_delivery_s3_config {
        bucket_name = aws_s3_bucket.bedrock_logs.id
        key_prefix  = "large-payloads/"
      }
    }

    # S3 — long-term archival
    s3_config {
      bucket_name = aws_s3_bucket.bedrock_logs.id
      key_prefix  = "invocation-logs/"
    }
  }
}

# IAM Role for Bedrock Logging
resource "aws_iam_role" "bedrock_logging" {
  name = "${var.project_name}-${var.environment}-bedrock-logging-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "bedrock.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "bedrock_logging" {
  name = "bedrock-logging-policy"
  role = aws_iam_role.bedrock_logging.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.bedrock.arn}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.bedrock_logs.arn}/*"
      }
    ]
  })
}

# ─── CloudWatch Alarms for AI Monitoring ─────────────────────

# High Bedrock error rate alarm
resource "aws_cloudwatch_metric_alarm" "bedrock_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-bedrock-high-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "InvocationErrors"
  namespace           = "AWS/Bedrock"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Bedrock model invocation error rate is high"
  alarm_actions       = var.alert_sns_topic_arn != "" ? [var.alert_sns_topic_arn] : []

  dimensions = {
    ModelId = "anthropic.claude-3-5-sonnet-20241022-v2:0"
  }

  tags = var.tags
}

# High Bedrock throttling alarm
resource "aws_cloudwatch_metric_alarm" "bedrock_throttles" {
  alarm_name          = "${var.project_name}-${var.environment}-bedrock-throttled"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "InvocationThrottles"
  namespace           = "AWS/Bedrock"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Bedrock model invocations are being throttled"
  alarm_actions       = var.alert_sns_topic_arn != "" ? [var.alert_sns_topic_arn] : []

  tags = var.tags
}
