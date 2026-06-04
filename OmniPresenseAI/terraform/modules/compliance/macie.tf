# ─────────────────────────────────────────────────────────────
# Amazon Macie — PII/PHI Detection
# ─────────────────────────────────────────────────────────────
# Compliance: HIPAA (PHI discovery), GDPR Art.30 (data mapping),
#             PCI-DSS (cardholder data detection)
# WAF Pillar: Security (Data protection)
# AI Lens:    Data governance, data classification
# ─────────────────────────────────────────────────────────────

resource "aws_macie2_account" "main" {}

# Classify the transcripts S3 bucket for PII/PHI
resource "aws_macie2_classification_job" "transcripts" {
  name     = "${var.project_name}-${var.environment}-transcript-scan"
  job_type = "SCHEDULED"

  s3_job_definition {
    bucket_definitions {
      account_id = data.aws_caller_identity.current.account_id
      buckets    = [var.transcripts_bucket_name]
    }

    scoping {
      includes {
        and {
          simple_scope_term {
            comparator = "STARTS_WITH"
            key        = "OBJECT_KEY"
            values     = ["transcripts/"]
          }
        }
      }
    }
  }

  schedule_frequency_details {
    weekly_schedule = "MONDAY"
  }

  sampling_percentage = 100

  custom_data_identifier_ids = []

  tags = merge(var.tags, {
    Name       = "${var.project_name}-${var.environment}-macie-scan"
    Compliance = "HIPAA,GDPR,PCI-DSS"
  })

  depends_on = [aws_macie2_account.main]
}

# EventBridge rule for HIGH severity Macie findings
resource "aws_cloudwatch_event_rule" "macie_findings" {
  name        = "${var.project_name}-${var.environment}-macie-pii-findings"
  description = "Alert on Macie PII/PHI findings"

  event_pattern = jsonencode({
    source      = ["aws.macie"]
    detail-type = ["Macie Finding"]
    detail = {
      severity = {
        description = ["High"]
      }
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "macie_sns" {
  rule      = aws_cloudwatch_event_rule.macie_findings.name
  target_id = "macie-to-sns"
  arn       = aws_sns_topic.guardduty_alerts.arn
}
