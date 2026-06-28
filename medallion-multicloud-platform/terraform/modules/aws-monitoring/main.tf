# =============================================================================
# AWS MONITORING MODULE — Compliance KPIs, Audit Dashboards, Alarms
# =============================================================================
# Implements Section IV audit KPIs:
#   - Identity/Audit: 100% immutable access log capture
#   - Data Integrity: 100% CMK encryption enforcement
#   - Vulnerability: SAST scan gate (handled in CI/CD)
#   - Pipeline State: Configuration drift detection
# =============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  tags = merge(var.common_tags, {
    Module      = "aws-monitoring"
    Cloud       = "aws"
    Environment = var.environment
    Compliance  = "hipaa-soc2-pci"
    ManagedBy   = "terraform"
  })
}

# =============================================================================
# SNS TOPIC — Compliance Violation Alerts
# =============================================================================
resource "aws_sns_topic" "compliance_alerts" {
  name              = "${local.name_prefix}-compliance-alerts"
  kms_master_key_id = var.logs_kms_key_id

  tags = local.tags
}

resource "aws_sns_topic_subscription" "compliance_email" {
  count     = length(var.alert_email_addresses)
  topic_arn = aws_sns_topic.compliance_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email_addresses[count.index]
}

# =============================================================================
# CLOUDWATCH ALARMS — Compliance Breach Detection
# =============================================================================

# Alarm: Unauthorized API calls (SOC 2 / HIPAA)
resource "aws_cloudwatch_log_metric_filter" "unauthorized_api_calls" {
  name           = "${local.name_prefix}-unauthorized-api-calls"
  log_group_name = var.cloudtrail_log_group_name
  pattern        = "{ ($.errorCode = \"*UnauthorizedAccess*\") || ($.errorCode = \"AccessDenied*\") }"

  metric_transformation {
    name          = "UnauthorizedAPICalls"
    namespace     = "${local.name_prefix}/Compliance"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "unauthorized_api_calls" {
  alarm_name          = "${local.name_prefix}-unauthorized-api-calls"
  alarm_description   = "COMPLIANCE: Unauthorized API call detected"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnauthorizedAPICalls"
  namespace           = "${local.name_prefix}/Compliance"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_actions       = [aws_sns_topic.compliance_alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = local.tags
}

# Alarm: Root account usage (PCI-DSS / SOC 2)
resource "aws_cloudwatch_log_metric_filter" "root_account_usage" {
  name           = "${local.name_prefix}-root-account-usage"
  log_group_name = var.cloudtrail_log_group_name
  pattern        = "{ $.userIdentity.type = \"Root\" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != \"AwsServiceEvent\" }"

  metric_transformation {
    name          = "RootAccountUsage"
    namespace     = "${local.name_prefix}/Compliance"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "root_account_usage" {
  alarm_name          = "${local.name_prefix}-root-account-usage"
  alarm_description   = "COMPLIANCE: Root account used — investigate immediately"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RootAccountUsage"
  namespace           = "${local.name_prefix}/Compliance"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_actions       = [aws_sns_topic.compliance_alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = local.tags
}

# Alarm: S3 bucket policy changes (data integrity)
resource "aws_cloudwatch_log_metric_filter" "s3_policy_changes" {
  name           = "${local.name_prefix}-s3-policy-changes"
  log_group_name = var.cloudtrail_log_group_name
  pattern        = "{ ($.eventSource = s3.amazonaws.com) && (($.eventName = PutBucketAcl) || ($.eventName = PutBucketPolicy) || ($.eventName = PutBucketCors) || ($.eventName = PutBucketLifecycle) || ($.eventName = PutBucketReplication) || ($.eventName = DeleteBucketPolicy) || ($.eventName = DeleteBucketCors) || ($.eventName = DeleteBucketLifecycle) || ($.eventName = DeleteBucketReplication)) }"

  metric_transformation {
    name          = "S3PolicyChanges"
    namespace     = "${local.name_prefix}/Compliance"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "s3_policy_changes" {
  alarm_name          = "${local.name_prefix}-s3-policy-changes"
  alarm_description   = "COMPLIANCE: S3 bucket policy modified — verify encryption and access controls"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "S3PolicyChanges"
  namespace           = "${local.name_prefix}/Compliance"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_actions       = [aws_sns_topic.compliance_alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = local.tags
}

# Alarm: KMS key deletion scheduled
resource "aws_cloudwatch_log_metric_filter" "kms_key_deletion" {
  name           = "${local.name_prefix}-kms-key-deletion"
  log_group_name = var.cloudtrail_log_group_name
  pattern        = "{ ($.eventSource = kms.amazonaws.com) && (($.eventName = DisableKey) || ($.eventName = ScheduleKeyDeletion)) }"

  metric_transformation {
    name          = "KMSKeyDeletion"
    namespace     = "${local.name_prefix}/Compliance"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "kms_key_deletion" {
  alarm_name          = "${local.name_prefix}-kms-key-deletion"
  alarm_description   = "CRITICAL: KMS key disabled or deletion scheduled — data integrity at risk"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "KMSKeyDeletion"
  namespace           = "${local.name_prefix}/Compliance"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_actions       = [aws_sns_topic.compliance_alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = local.tags
}

# =============================================================================
# CLOUDWATCH DASHBOARD — Pipeline & Compliance KPIs
# =============================================================================
resource "aws_cloudwatch_dashboard" "compliance" {
  dashboard_name = "${local.name_prefix}-compliance-kpis"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Unauthorized API Calls (Target: 0)"
          metrics = [["${local.name_prefix}/Compliance", "UnauthorizedAPICalls", { stat = "Sum", period = 3600 }]]
          view    = "timeSeries"
          region  = var.aws_region
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Root Account Usage (Target: 0)"
          metrics = [["${local.name_prefix}/Compliance", "RootAccountUsage", { stat = "Sum", period = 3600 }]]
          view    = "timeSeries"
          region  = var.aws_region
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "S3 Policy Modifications"
          metrics = [["${local.name_prefix}/Compliance", "S3PolicyChanges", { stat = "Sum", period = 3600 }]]
          view    = "timeSeries"
          region  = var.aws_region
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "KMS Key Deletion Events (Target: 0)"
          metrics = [["${local.name_prefix}/Compliance", "KMSKeyDeletion", { stat = "Sum", period = 3600 }]]
          view    = "timeSeries"
          region  = var.aws_region
        }
      },
      {
        type   = "text"
        x      = 0
        y      = 12
        width  = 24
        height = 3
        properties = {
          markdown = "## Compliance Audit KPIs\n| Metric | Target | Standard |\n|--------|--------|----------|\n| Access Log Trail | 100% immutable capture | HIPAA/SOC 2 |\n| CMK Encryption | 100% enforced | PCI-DSS 3.4 |\n| SAST Vulnerabilities | 0 critical | PCI-DSS 6.5 |\n| Config Drift | 0 gaps | SOC 2 CC8.1 |"
        }
      }
    ]
  })
}

# =============================================================================
# AWS CONFIG CONFORMANCE PACK — HIPAA/PCI-DSS
# =============================================================================
resource "aws_config_conformance_pack" "hipaa" {
  name = "${local.name_prefix}-hipaa-conformance"

  template_body = <<-EOT
    Resources:
      S3BucketEncryption:
        Type: AWS::Config::ConfigRule
        Properties:
          ConfigRuleName: s3-bucket-server-side-encryption-enabled
          Source:
            Owner: AWS
            SourceIdentifier: S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED
      S3BucketPublicReadProhibited:
        Type: AWS::Config::ConfigRule
        Properties:
          ConfigRuleName: s3-bucket-public-read-prohibited
          Source:
            Owner: AWS
            SourceIdentifier: S3_BUCKET_PUBLIC_READ_PROHIBITED
      S3BucketPublicWriteProhibited:
        Type: AWS::Config::ConfigRule
        Properties:
          ConfigRuleName: s3-bucket-public-write-prohibited
          Source:
            Owner: AWS
            SourceIdentifier: S3_BUCKET_PUBLIC_WRITE_PROHIBITED
      CloudTrailEnabled:
        Type: AWS::Config::ConfigRule
        Properties:
          ConfigRuleName: cloudtrail-enabled
          Source:
            Owner: AWS
            SourceIdentifier: CLOUD_TRAIL_ENABLED
      CloudTrailEncryption:
        Type: AWS::Config::ConfigRule
        Properties:
          ConfigRuleName: cloud-trail-encryption-enabled
          Source:
            Owner: AWS
            SourceIdentifier: CLOUD_TRAIL_ENCRYPTION_ENABLED
      VPCFlowLogsEnabled:
        Type: AWS::Config::ConfigRule
        Properties:
          ConfigRuleName: vpc-flow-logs-enabled
          Source:
            Owner: AWS
            SourceIdentifier: VPC_FLOW_LOGS_ENABLED
  EOT

  depends_on = [aws_sns_topic.compliance_alerts]
}
