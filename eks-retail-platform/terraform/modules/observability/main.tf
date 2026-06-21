# ─────────────────────────────────────────────────────────────────────────────
# Observability Module — CloudWatch Log Groups & Dashboards
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "application" {
  name              = "/eks/${var.cluster_name}/retail-apps"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(var.common_tags, {
    Name       = "${var.name_prefix}-app-logs"
    Compliance = "SOC2,HIPAA"
  })
}

resource "aws_cloudwatch_log_group" "payment" {
  name              = "/eks/${var.cluster_name}/payment"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(var.common_tags, {
    Name       = "${var.name_prefix}-payment-logs"
    Compliance = "PCI-DSS,HIPAA"
  })
}

resource "aws_cloudwatch_log_group" "istio" {
  name              = "/eks/${var.cluster_name}/istio-system"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-istio-logs"
  })
}

resource "aws_cloudwatch_log_group" "fluentbit" {
  name              = "/eks/${var.cluster_name}/fluentbit"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-fluentbit-logs"
  })
}

# ─── FluentBit IRSA Role ────────────────────────────────────────────────────

resource "aws_iam_role" "fluentbit" {
  name = "${var.name_prefix}-fluentbit-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
          "${var.oidc_provider_url}:sub" = "system:serviceaccount:fluentbit:fluentbit"
        }
      }
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "fluentbit" {
  name = "cloudwatch-logs-access"
  role = aws_iam_role.fluentbit.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/eks/${var.cluster_name}/*"
    }]
  })
}

# ─── CloudWatch Dashboard ───────────────────────────────────────────────────

resource "aws_cloudwatch_dashboard" "retail_platform" {
  dashboard_name = "${var.name_prefix}-retail-platform"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "SQS - Order Queue Depth (KEDA Trigger)"
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", "${var.name_prefix}-order-queue.fifo"]
          ]
          period = 60
          stat   = "Average"
          region = var.aws_region
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "SQS - Notification Queue Depth (KEDA Trigger)"
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", "${var.name_prefix}-notification-queue"]
          ]
          period = 60
          stat   = "Average"
          region = var.aws_region
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "Aurora - Database Connections"
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBClusterIdentifier", "${var.name_prefix}-aurora"]
          ]
          period = 60
          stat   = "Average"
          region = var.aws_region
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "Aurora - CPU Utilization"
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBClusterIdentifier", "${var.name_prefix}-aurora"]
          ]
          period = 60
          stat   = "Average"
          region = var.aws_region
        }
      }
    ]
  })
}
