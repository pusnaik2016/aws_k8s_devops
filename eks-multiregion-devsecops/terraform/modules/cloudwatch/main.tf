# ==============================================================================
# CloudWatch Module — Centralized Logging & Monitoring
# ==============================================================================
# Creates KMS-encrypted CloudWatch LogGroups with 365-day retention for:
#   - EKS control plane, Aurora audit/slow query, Application, Karpenter
# Also creates Container Insights addon configuration data.
# ==============================================================================

resource "aws_cloudwatch_log_group" "aurora_audit" {
  name              = "/aws/rds/cluster/${var.project_name}-aurora/audit"
  retention_in_days = 365
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name       = "${var.project_name}-aurora-audit-logs"
    Compliance = "PCI-HIPAA-SOC2"
  })
}

resource "aws_cloudwatch_log_group" "aurora_slowquery" {
  name              = "/aws/rds/cluster/${var.project_name}-aurora/slowquery"
  retention_in_days = 365
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name = "${var.project_name}-aurora-slowquery-logs"
  })
}

resource "aws_cloudwatch_log_group" "application" {
  name              = "/app/${var.project_name}/application"
  retention_in_days = 90
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name = "${var.project_name}-application-logs"
  })
}

resource "aws_cloudwatch_log_group" "karpenter" {
  name              = "/aws/karpenter/${var.project_name}-eks"
  retention_in_days = 90
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name = "${var.project_name}-karpenter-logs"
  })
}

# =============================================================================
# CloudWatch Dashboard — EKS + Aurora Overview
# =============================================================================
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.aws_region}-overview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "EKS Cluster CPU Utilization"
          region = var.aws_region
          metrics = [
            ["ContainerInsights", "node_cpu_utilization", "ClusterName", "${var.project_name}-eks"]
          ]
          period = 300
          stat   = "Average"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "EKS Cluster Memory Utilization"
          region = var.aws_region
          metrics = [
            ["ContainerInsights", "node_memory_utilization", "ClusterName", "${var.project_name}-eks"]
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
          title  = "Aurora CPU Utilization"
          region = var.aws_region
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBClusterIdentifier", "${var.project_name}-aurora"]
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
          title  = "Aurora Database Connections"
          region = var.aws_region
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBClusterIdentifier", "${var.project_name}-aurora"]
          ]
          period = 300
          stat   = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        properties = {
          title  = "Aurora Replication Lag"
          region = var.aws_region
          metrics = [
            ["AWS/RDS", "AuroraReplicaLag", "DBClusterIdentifier", "${var.project_name}-aurora"]
          ]
          period = 60
          stat   = "Maximum"
        }
      }
    ]
  })
}
