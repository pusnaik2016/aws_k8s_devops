# ==============================================================================
# Monitoring — CloudWatch Alarms + CloudTrail (Primary Region)
# ==============================================================================

# =============================================================================
# CloudTrail — Multi-region audit trail
# =============================================================================
resource "aws_cloudtrail" "main" {
  name                          = "${var.project_name}-trail"
  s3_bucket_name                = module.s3_audit_logs.bucket_id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  kms_key_id                    = module.kms.s3_key_arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::"]
    }
  }

  tags = merge(local.common_tags, {
    Name       = "${var.project_name}-trail"
    Compliance = "PCI-HIPAA-SOC2"
  })
}

# =============================================================================
# SNS Topic — Security alerts (KMS-encrypted)
# =============================================================================
resource "aws_sns_topic" "security_alerts" {
  name              = "${var.project_name}-security-alerts"
  kms_master_key_id = module.kms.sns_key_id

  tags = merge(local.common_tags, {
    Name       = "${var.project_name}-security-alerts"
    Compliance = "PCI-HIPAA-SOC2"
  })
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.security_alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.security_alert_email
}

# =============================================================================
# CloudTrail → CloudWatch Logs (for metric filters)
# =============================================================================
resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${var.project_name}"
  retention_in_days = 365
  kms_key_id        = module.kms.eks_key_arn

  tags = merge(local.common_tags, { Compliance = "PCI-HIPAA-SOC2" })
}

resource "aws_iam_role" "cloudtrail_cw" {
  name = "${var.project_name}-cloudtrail-cw-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "cloudtrail_cw" {
  name = "${var.project_name}-cloudtrail-cw-policy"
  role = aws_iam_role.cloudtrail_cw.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
    }]
  })
}

# =============================================================================
# Alarm 1: Root Account Usage
# =============================================================================
resource "aws_cloudwatch_log_metric_filter" "root_login" {
  name           = "${var.project_name}-root-login"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ $.userIdentity.type = \"Root\" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != \"AwsServiceEvent\" }"

  metric_transformation {
    name      = "RootAccountUsage"
    namespace = "${var.project_name}/SecurityMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "root_login" {
  alarm_name          = "${var.project_name}-root-account-usage"
  alarm_description   = "CRITICAL: Root account was used"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "RootAccountUsage"
  namespace           = "${var.project_name}/SecurityMetrics"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  tags                = { Compliance = "PCI-HIPAA-SOC2" }
}

# =============================================================================
# Alarm 2: IAM Policy Changes
# =============================================================================
resource "aws_cloudwatch_log_metric_filter" "iam_changes" {
  name           = "${var.project_name}-iam-changes"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ ($.eventName = DeleteGroupPolicy) || ($.eventName = DeleteRolePolicy) || ($.eventName = PutGroupPolicy) || ($.eventName = PutRolePolicy) || ($.eventName = CreatePolicy) || ($.eventName = AttachRolePolicy) || ($.eventName = DetachRolePolicy) }"

  metric_transformation {
    name      = "IAMPolicyChanges"
    namespace = "${var.project_name}/SecurityMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "iam_changes" {
  alarm_name          = "${var.project_name}-iam-policy-changes"
  alarm_description   = "IAM policy modified"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "IAMPolicyChanges"
  namespace           = "${var.project_name}/SecurityMetrics"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  tags                = { Compliance = "PCI-SOC2" }
}

# =============================================================================
# Alarm 3: CloudTrail Disabled
# =============================================================================
resource "aws_cloudwatch_log_metric_filter" "cloudtrail_disabled" {
  name           = "${var.project_name}-cloudtrail-disabled"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ ($.eventName = StopLogging) || ($.eventName = DeleteTrail) || ($.eventName = UpdateTrail) }"

  metric_transformation {
    name      = "CloudTrailChanges"
    namespace = "${var.project_name}/SecurityMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "cloudtrail_disabled" {
  alarm_name          = "${var.project_name}-cloudtrail-disabled"
  alarm_description   = "CRITICAL: CloudTrail tampered"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "CloudTrailChanges"
  namespace           = "${var.project_name}/SecurityMetrics"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  tags                = { Compliance = "PCI-HIPAA-SOC2" }
}

# =============================================================================
# Alarm 4: Unauthorized API Calls
# =============================================================================
resource "aws_cloudwatch_log_metric_filter" "unauthorized_api" {
  name           = "${var.project_name}-unauthorized-api"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ ($.errorCode = \"*UnauthorizedAccess*\") || ($.errorCode = \"AccessDenied*\") }"

  metric_transformation {
    name      = "UnauthorizedAPICalls"
    namespace = "${var.project_name}/SecurityMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "unauthorized_api" {
  alarm_name          = "${var.project_name}-unauthorized-api-calls"
  alarm_description   = "Spike in unauthorized API calls"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "UnauthorizedAPICalls"
  namespace           = "${var.project_name}/SecurityMetrics"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  tags                = { Compliance = "PCI-HIPAA-SOC2" }
}

# =============================================================================
# Alarm 5: Security Group Changes
# =============================================================================
resource "aws_cloudwatch_log_metric_filter" "sg_changes" {
  name           = "${var.project_name}-sg-changes"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ ($.eventName = AuthorizeSecurityGroupIngress) || ($.eventName = RevokeSecurityGroupIngress) || ($.eventName = CreateSecurityGroup) || ($.eventName = DeleteSecurityGroup) }"

  metric_transformation {
    name      = "SecurityGroupChanges"
    namespace = "${var.project_name}/SecurityMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "sg_changes" {
  alarm_name          = "${var.project_name}-sg-changes"
  alarm_description   = "Security group rules modified"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "SecurityGroupChanges"
  namespace           = "${var.project_name}/SecurityMetrics"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  tags                = { Compliance = "PCI-SOC2" }
}

# =============================================================================
# Alarm 6: Aurora CPU High
# =============================================================================
resource "aws_cloudwatch_metric_alarm" "aurora_cpu" {
  alarm_name          = "${var.project_name}-aurora-cpu-high"
  alarm_description   = "Aurora CPU > 80%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.primary.cluster_identifier
  }

  tags = { Component = "aurora" }
}

# =============================================================================
# Alarm 7: Aurora Replication Lag
# =============================================================================
resource "aws_cloudwatch_metric_alarm" "aurora_replication_lag" {
  alarm_name          = "${var.project_name}-aurora-replication-lag"
  alarm_description   = "Aurora replication lag > 100ms"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "AuroraReplicaLag"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Maximum"
  threshold           = 100
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.primary.cluster_identifier
  }

  tags = { Component = "aurora" }
}
