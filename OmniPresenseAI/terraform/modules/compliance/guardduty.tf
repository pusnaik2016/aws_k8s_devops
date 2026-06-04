# ─────────────────────────────────────────────────────────────
# AWS GuardDuty — Threat Detection
# ─────────────────────────────────────────────────────────────
# Compliance: PCI-DSS 11.4 (intrusion detection),
#             HIPAA §164.312(a)(1), SOX monitoring
# WAF Pillar: Security (Detective controls)
# ─────────────────────────────────────────────────────────────

resource "aws_guardduty_detector" "main" {
  enable = true

  datasources {
    # EKS audit log monitoring
    kubernetes {
      audit_logs {
        enable = true
      }
    }

    # S3 data event monitoring
    s3_logs {
      enable = true
    }

    # Malware scanning on EBS volumes
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  finding_publishing_frequency = "FIFTEEN_MINUTES"

  tags = merge(var.tags, {
    Name       = "${var.project_name}-${var.environment}-guardduty"
    Compliance = "PCI-DSS,HIPAA"
  })
}

# SNS Topic for GuardDuty findings
resource "aws_sns_topic" "guardduty_alerts" {
  name              = "${var.project_name}-${var.environment}-guardduty-alerts"
  kms_master_key_id = var.kms_s3_key_arn

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-guardduty-alerts"
  })
}

resource "aws_sns_topic_subscription" "guardduty_email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.guardduty_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# EventBridge rule to forward HIGH/CRITICAL findings to SNS
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "${var.project_name}-${var.environment}-guardduty-high-findings"
  description = "Forward HIGH/CRITICAL GuardDuty findings to SNS"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 7] }]
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "guardduty_sns" {
  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  target_id = "guardduty-to-sns"
  arn       = aws_sns_topic.guardduty_alerts.arn
}

resource "aws_sns_topic_policy" "guardduty_alerts" {
  arn = aws_sns_topic.guardduty_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sns:Publish"
      Resource  = aws_sns_topic.guardduty_alerts.arn
    }]
  })
}
