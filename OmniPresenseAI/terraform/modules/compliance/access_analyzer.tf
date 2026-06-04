# ─────────────────────────────────────────────────────────────
# IAM Access Analyzer — External Access Detection
# ─────────────────────────────────────────────────────────────
# Compliance: SOX (access reviews), PCI-DSS 7.1,
#             HIPAA §164.312(a)(1)
# WAF Pillar: Security (IAM)
# ─────────────────────────────────────────────────────────────

resource "aws_accessanalyzer_analyzer" "main" {
  analyzer_name = "${var.project_name}-${var.environment}-access-analyzer"
  type          = "ACCOUNT"

  tags = merge(var.tags, {
    Name       = "${var.project_name}-${var.environment}-access-analyzer"
    Compliance = "SOX,PCI-DSS,HIPAA"
  })
}

# EventBridge rule for Access Analyzer findings
resource "aws_cloudwatch_event_rule" "access_analyzer" {
  name        = "${var.project_name}-${var.environment}-access-analyzer-findings"
  description = "Alert on IAM Access Analyzer external access findings"

  event_pattern = jsonencode({
    source      = ["aws.access-analyzer"]
    detail-type = ["Access Analyzer Finding"]
    detail = {
      status = ["ACTIVE"]
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "access_analyzer_sns" {
  rule      = aws_cloudwatch_event_rule.access_analyzer.name
  target_id = "access-analyzer-to-sns"
  arn       = aws_sns_topic.guardduty_alerts.arn
}
