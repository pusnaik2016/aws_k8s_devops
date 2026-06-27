# ==============================================================================
# CloudWatch Alarms + SNS — Security Event Monitoring
# ==============================================================================
# Compliance requirements addressed:
#   PCI DSS Req 10.6: Review logs daily; alert on anomalies
#   PCI DSS Req 8.2 : Alert on root account usage
#   SOC 2 CC7.2     : Monitor for security events and anomalies
#   SOC 2 CC6.1     : Logical access controls — alert on policy changes
#   HIPAA §164.308  : Information system activity review
#
# Alarms configured:
#   1. Root account login — any usage is a critical violation
#   2. IAM policy changes — unauthorized privilege escalation
#   3. WAF block spike — active attack or DDoS
#   4. Unauthorized API calls — credential misuse
#   5. CloudTrail disabled — audit log tampering attempt
#   6. EKS API server errors — cluster access anomalies
# ==============================================================================

# =============================================================================
# SNS Topic — Security alert notifications
# =============================================================================
resource "aws_sns_topic" "security_alerts" {
  name              = "${var.project_name}-security-alerts"
  kms_master_key_id = aws_kms_key.eks.id # encrypt SNS messages at rest

  tags = {
    Name       = "${var.project_name}-security-alerts"
    Compliance = "PCI-HIPAA-SOC2"
  }
}

resource "aws_sns_topic_subscription" "security_alerts_email" {
  count     = var.security_alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.security_alert_email
}

# =============================================================================
# CloudWatch Log Metric Filters + Alarms (sourced from CloudTrail)
# =============================================================================
# CloudTrail sends management events to CloudWatch Logs so we can create
# metric filters that count specific API call patterns and alarm on them.

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${var.project_name}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.eks.arn

  tags = {
    Name       = "${var.project_name}-cloudtrail-logs"
    Compliance = "PCI-HIPAA-SOC2"
  }
}

# IAM role allowing CloudTrail to write to CloudWatch Logs
resource "aws_iam_role" "cloudtrail_cloudwatch" {
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

resource "aws_iam_role_policy" "cloudtrail_cloudwatch" {
  name = "${var.project_name}-cloudtrail-cw-policy"
  role = aws_iam_role.cloudtrail_cloudwatch.id

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

# Attach CloudWatch Logs delivery to the CloudTrail resource
resource "aws_cloudtrail_event_data_store" "cloudwatch_delivery" {
  count = 0 # placeholder — CloudWatch delivery is set via aws_cloudtrail resource below
  name  = "${var.project_name}-cw-delivery"
}

# Update CloudTrail to also deliver to CloudWatch Logs for metric filters
resource "aws_cloudtrail" "cloudwatch" {
  # This extends the main trail in cloudtrail.tf with CW Logs delivery.
  # We use a separate named trail to avoid circular dependency.
  name                          = "${var.project_name}-trail-cw"
  s3_bucket_name                = aws_s3_bucket.audit_logs.id
  include_global_service_events = true
  is_multi_region_trail         = false # single region for CW Logs delivery
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.eks.arn

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cloudwatch.arn

  depends_on = [aws_s3_bucket_policy.audit_logs]

  tags = {
    Name       = "${var.project_name}-trail-cw"
    Compliance = "PCI-HIPAA-SOC2"
  }
}

# ---------------------------------------------------------------------------
# Alarm 1: Root account usage — PCI Req 8.2, SOC 2 CC6
# Any use of the root account is a critical security event
# ---------------------------------------------------------------------------
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
  alarm_description   = "PCI Req 8.2 / SOC2 CC6: Root account was used — investigate immediately"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "RootAccountUsage"
  namespace           = "${var.project_name}/SecurityMetrics"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  tags = { Compliance = "PCI-HIPAA-SOC2" }
}

# ---------------------------------------------------------------------------
# Alarm 2: IAM policy changes — SOC 2 CC6.1, PCI Req 7
# Unauthorized privilege escalation detection
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_metric_filter" "iam_policy_changes" {
  name           = "${var.project_name}-iam-policy-changes"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ ($.eventName = DeleteGroupPolicy) || ($.eventName = DeleteRolePolicy) || ($.eventName = DeleteUserPolicy) || ($.eventName = PutGroupPolicy) || ($.eventName = PutRolePolicy) || ($.eventName = PutUserPolicy) || ($.eventName = CreatePolicy) || ($.eventName = DeletePolicy) || ($.eventName = AttachRolePolicy) || ($.eventName = DetachRolePolicy) }"

  metric_transformation {
    name      = "IAMPolicyChanges"
    namespace = "${var.project_name}/SecurityMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "iam_policy_changes" {
  alarm_name          = "${var.project_name}-iam-policy-changes"
  alarm_description   = "SOC2 CC6.1 / PCI Req 7: IAM policy was created, modified, or deleted"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "IAMPolicyChanges"
  namespace           = "${var.project_name}/SecurityMetrics"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  tags = { Compliance = "PCI-SOC2" }
}

# ---------------------------------------------------------------------------
# Alarm 3: CloudTrail disabled or stopped — PCI Req 10.3
# Tampering with audit logs is a critical violation
# ---------------------------------------------------------------------------
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
  alarm_description   = "PCI Req 10.3: CloudTrail was stopped or deleted — audit log tampering"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "CloudTrailChanges"
  namespace           = "${var.project_name}/SecurityMetrics"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  tags = { Compliance = "PCI-HIPAA-SOC2" }
}

# ---------------------------------------------------------------------------
# Alarm 4: Unauthorized API calls — SOC 2 CC7.2, HIPAA §164.308
# Detects credential misuse or misconfigured IAM
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_metric_filter" "unauthorized_api_calls" {
  name           = "${var.project_name}-unauthorized-api"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ ($.errorCode = \"*UnauthorizedAccess*\") || ($.errorCode = \"AccessDenied*\") }"

  metric_transformation {
    name      = "UnauthorizedAPICalls"
    namespace = "${var.project_name}/SecurityMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "unauthorized_api_calls" {
  alarm_name          = "${var.project_name}-unauthorized-api-calls"
  alarm_description   = "SOC2 CC7.2 / HIPAA: Spike in unauthorized API calls — possible credential misuse"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "UnauthorizedAPICalls"
  namespace           = "${var.project_name}/SecurityMetrics"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  tags = { Compliance = "PCI-HIPAA-SOC2" }
}

# ---------------------------------------------------------------------------
# Alarm 5: WAF block spike — PCI Req 6, SOC 2 CC7
# Detects active attacks or DDoS against the ALB
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "waf_blocks" {
  alarm_name          = "${var.project_name}-waf-block-spike"
  alarm_description   = "PCI Req 6 / SOC2 CC7: WAF is blocking a high volume of requests — possible attack"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = 300
  statistic           = "Sum"
  threshold           = var.waf_block_alarm_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  dimensions = {
    WebACL = aws_wafv2_web_acl.app.name
    Region = var.aws_region
    Rule   = "ALL"
  }

  tags = { Compliance = "PCI-SOC2" }
}

# ---------------------------------------------------------------------------
# Alarm 6: Security group changes — PCI Req 1, SOC 2 CC6
# Network firewall rule changes must be reviewed
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_metric_filter" "sg_changes" {
  name           = "${var.project_name}-sg-changes"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ ($.eventName = AuthorizeSecurityGroupIngress) || ($.eventName = AuthorizeSecurityGroupEgress) || ($.eventName = RevokeSecurityGroupIngress) || ($.eventName = RevokeSecurityGroupEgress) || ($.eventName = CreateSecurityGroup) || ($.eventName = DeleteSecurityGroup) }"

  metric_transformation {
    name      = "SecurityGroupChanges"
    namespace = "${var.project_name}/SecurityMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "sg_changes" {
  alarm_name          = "${var.project_name}-security-group-changes"
  alarm_description   = "PCI Req 1 / SOC2 CC6: Security group rules were modified"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "SecurityGroupChanges"
  namespace           = "${var.project_name}/SecurityMetrics"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  tags = { Compliance = "PCI-SOC2" }
}
