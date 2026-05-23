###############################################################################
# Notifications Module — SNS Topic + Email Subscription
###############################################################################

resource "aws_sns_topic" "cost_alerts" {
  name              = "${var.topic_name}-${var.environment}"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Name      = "${var.topic_name}-${var.environment}"
    Component = "notifications"
  }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.cost_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

###############################################################################
# SNS Topic Policy — allow Lambda & EventBridge to publish
###############################################################################
resource "aws_sns_topic_policy" "default" {
  arn    = aws_sns_topic.cost_alerts.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    sid     = "AllowLambdaPublish"
    effect  = "Allow"
    actions = ["sns:Publish"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    resources = [aws_sns_topic.cost_alerts.arn]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid     = "AllowAccountPublish"
    effect  = "Allow"
    actions = ["sns:Publish"]

    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.account_id]
    }

    resources = [aws_sns_topic.cost_alerts.arn]
  }
}
