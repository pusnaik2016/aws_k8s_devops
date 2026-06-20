# ============================================================================
# AWS Monitoring — CloudWatch, X-Ray, SNS, Route 53 Health Checks
# ============================================================================

terraform {
  required_version = ">= 1.5"
}

# ──────────────────────────────────────────────────────────────────────────────
# SNS Topic — Alerts
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_sns_topic" "alerts" {
  name              = "${var.project}-${var.environment}-alerts"
  kms_master_key_id = var.kms_key_arn

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-alerts"
  })
}

resource "aws_sns_topic_subscription" "email" {
  count     = length(var.alert_emails)
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_emails[count.index]
}

# ──────────────────────────────────────────────────────────────────────────────
# CloudWatch Log Groups
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.project}-${var.environment}-eks/cluster"
  retention_in_days = var.environment == "prod" ? 365 : 30
  kms_key_id        = var.kms_key_arn

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-eks-logs"
  })
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/${var.project}-${var.environment}-flow-logs"
  retention_in_days = var.environment == "prod" ? 365 : 30
  kms_key_id        = var.kms_key_arn

  tags = merge(var.common_tags, {
    Name       = "${var.project}-${var.environment}-vpc-flow-logs"
    Compliance = "hipaa-audit"
  })
}

# ──────────────────────────────────────────────────────────────────────────────
# CloudWatch Alarms — Critical Metrics
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "aurora_cpu" {
  alarm_name          = "${var.project}-${var.environment}-aurora-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Aurora CPU > 80% for 15 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBClusterIdentifier = "${var.project}-${var.environment}-aurora-primary"
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "aurora_replication_lag" {
  alarm_name          = "${var.project}-${var.environment}-aurora-replication-lag"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "AuroraReplicaLag"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Maximum"
  threshold           = 300000  # 5 minutes in ms
  alarm_description   = "Aurora replication lag > 5 min — DR RPO at risk"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBClusterIdentifier = "${var.project}-${var.environment}-aurora-primary"
  }

  tags = merge(var.common_tags, {
    AlertType = "dr-critical"
  })
}

resource "aws_cloudwatch_metric_alarm" "eks_node_cpu" {
  alarm_name          = "${var.project}-${var.environment}-eks-node-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "node_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "EKS node CPU > 85%"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = "${var.project}-${var.environment}-eks"
  }

  tags = var.common_tags
}

# ──────────────────────────────────────────────────────────────────────────────
# Route 53 Health Check — Primary Endpoint (for DR failover)
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_route53_health_check" "primary" {
  fqdn              = var.primary_domain
  port               = 443
  type               = "HTTPS"
  resource_path      = "/health"
  failure_threshold  = 3
  request_interval   = 10

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-primary-health-check"
  })
}

resource "aws_cloudwatch_metric_alarm" "health_check" {
  alarm_name          = "${var.project}-${var.environment}-primary-unhealthy"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "Primary endpoint unhealthy — DR failover may trigger"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    HealthCheckId = aws_route53_health_check.primary.id
  }

  tags = merge(var.common_tags, {
    AlertType = "dr-critical"
  })
}

# ──────────────────────────────────────────────────────────────────────────────
# CloudWatch Dashboard
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project}-${var.environment}-overview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "EKS Cluster CPU"
          metrics = [["ContainerInsights", "node_cpu_utilization", "ClusterName", "${var.project}-${var.environment}-eks"]]
          period  = 300
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
          title   = "Aurora CPU & Connections"
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBClusterIdentifier", "${var.project}-${var.environment}-aurora-primary"],
            ["AWS/RDS", "DatabaseConnections", "DBClusterIdentifier", "${var.project}-${var.environment}-aurora-primary"]
          ]
          period = 300
          region = var.aws_region
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 24
        height = 6
        properties = {
          title   = "DR Health — Primary Endpoint & Replication Lag"
          metrics = [
            ["AWS/Route53", "HealthCheckStatus", "HealthCheckId", aws_route53_health_check.primary.id],
            ["AWS/RDS", "AuroraReplicaLag", "DBClusterIdentifier", "${var.project}-${var.environment}-aurora-primary"]
          ]
          period = 60
          region = var.aws_region
        }
      }
    ]
  })
}
