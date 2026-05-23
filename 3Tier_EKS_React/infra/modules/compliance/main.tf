# =============================================================================
# Compliance & DR Module — CloudTrail, GuardDuty, DR resources
# Project: 3-Tier EKS Application
# Author: Pushparaj Naik
# Compliance: GDPR, SOC2
# =============================================================================

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.dr_region]
    }
  }
}

# --- CloudTrail ---
resource "aws_cloudtrail" "main" {
  name                          = "${var.prefix}-${var.environment}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true
  enable_log_file_validation    = true
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_cw.arn
  tags                          = { Name = "${var.prefix}-${var.environment}-cloudtrail" }
}

resource "aws_s3_bucket" "cloudtrail" {
  bucket        = "${var.prefix}-${var.environment}-trail-${var.account_id}"
  force_destroy = var.environment != "prod"
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket                  = aws_s3_bucket.cloudtrail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.cloudtrail.arn
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${var.account_id}/*"
        Condition = { StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" } }
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${var.prefix}-${var.environment}"
  retention_in_days = 365
}

resource "aws_iam_role" "cloudtrail_cw" {
  name = "${var.prefix}-${var.environment}-trail-cw-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "cloudtrail.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "cloudtrail_cw" {
  name = "${var.prefix}-${var.environment}-trail-cw-policy"
  role = aws_iam_role.cloudtrail_cw.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*" }]
  })
}

# --- GuardDuty ---
resource "aws_guardduty_detector" "main" {
  count  = var.enable_guardduty ? 1 : 0
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
  }
}

# =============================================================================
# Disaster Recovery — Cross-region snapshots, alarms
# =============================================================================

# Automated RDS snapshot copy to DR region
resource "aws_db_event_subscription" "rds_events" {
  name      = "${var.prefix}-${var.environment}-rds-events"
  sns_topic = aws_sns_topic.rds_events.arn

  source_type = "db-instance"
  source_ids  = [var.db_instance_identifier]

  event_categories = ["availability", "deletion", "failover", "failure", "recovery", "restoration"]
}

resource "aws_sns_topic" "rds_events" {
  name = "${var.prefix}-${var.environment}-rds-events"
  tags = { Name = "${var.prefix}-${var.environment}-rds-events" }
}

# DR KMS key in secondary region for snapshot encryption
resource "aws_kms_key" "dr_kms" {
  count                   = var.enable_dr ? 1 : 0
  provider                = aws.dr_region
  description             = "DR KMS key for cross-region RDS snapshot encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = { Name = "${var.prefix}-${var.environment}-dr-kms" }
}

# CloudWatch Alarm for RDS CPU (Operational Excellence)
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.prefix}-${var.environment}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS CPU utilization above 80%"
  dimensions          = { DBInstanceIdentifier = var.db_instance_identifier }
}

# CloudWatch Alarm for RDS Free Storage
resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  alarm_name          = "${var.prefix}-${var.environment}-rds-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 5368709120 # 5GB in bytes
  alarm_description   = "RDS free storage below 5GB"
  dimensions          = { DBInstanceIdentifier = var.db_instance_identifier }
}
