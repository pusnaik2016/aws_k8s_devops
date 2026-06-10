# ─────────────────────────────────────────────────────────────────────────────
# AWS Monitoring — CloudWatch, X-Ray, Prometheus/Grafana via Helm
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }

  backend "s3" {
    bucket         = "medcloud-terraform-state"
    key            = "aws/monitoring/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "medcloud-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = merge(var.common_tags, { Component = "monitoring" })
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ─── CloudWatch Dashboard ───────────────────────────────────────────────────

resource "aws_cloudwatch_dashboard" "medcloud" {
  dashboard_name = "${local.name_prefix}-platform-overview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "EKS Cluster CPU Utilization"
          metrics = [
            ["ContainerInsights", "node_cpu_utilization", "ClusterName", "${local.name_prefix}-eks"]
          ]
          period = 300
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
          title   = "Aurora Database Connections"
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBClusterIdentifier", "${local.name_prefix}-aurora-primary"]
          ]
          period = 300
          stat   = "Average"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "ElastiCache Redis Memory"
          metrics = [
            ["AWS/ElastiCache", "DatabaseMemoryUsagePercentage", "ReplicationGroupId", "${local.name_prefix}-redis"]
          ]
          period = 300
          stat   = "Average"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "WAF Blocked Requests"
          metrics = [
            ["AWS/WAFV2", "BlockedRequests", "WebACL", "${local.name_prefix}-waf", "Region", var.aws_region, "Rule", "ALL"]
          ]
          period = 300
          stat   = "Sum"
        }
      }
    ]
  })
}

# ─── CloudWatch Alarms ──────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "aurora_cpu" {
  alarm_name          = "${local.name_prefix}-aurora-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Aurora CPU utilization > 80% for 15 minutes"
  alarm_actions       = [] # Add SNS topic ARN

  dimensions = {
    DBClusterIdentifier = "${local.name_prefix}-aurora-primary"
  }

  tags = { Severity = "high" }
}

resource "aws_cloudwatch_metric_alarm" "redis_memory" {
  alarm_name          = "${local.name_prefix}-redis-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "Redis memory usage > 85%"
  alarm_actions       = []

  dimensions = {
    ReplicationGroupId = "${local.name_prefix}-redis"
  }

  tags = { Severity = "warning" }
}

# ─── SNS Topic for Alerts ───────────────────────────────────────────────────

resource "aws_sns_topic" "alerts" {
  name              = "${local.name_prefix}-platform-alerts"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Name = "${local.name_prefix}-alerts"
  }
}

output "dashboard_url" {
  value = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.medcloud.dashboard_name}"
}

output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}
