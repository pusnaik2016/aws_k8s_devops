# ══════════════════════════════════════════════════════════════════════════════
# Module: observability
# CloudWatch dashboard, metric filters, and alarms for AgentCore Memory.
# ══════════════════════════════════════════════════════════════════════════════

# ── Metric Filters (parse structured log markers from Lambda) ────────────────
# Uses simple substring match — Lambda's Python logger outputs tab-separated
# lines, so field-position patterns never match.

resource "aws_cloudwatch_log_metric_filter" "memory_saves" {
  name           = "${var.name}-memory-saves"
  log_group_name = var.lambda_log_group_name
  pattern        = "MEMORY_SAVED"

  metric_transformation {
    name      = "MemorySaveCount"
    namespace = "${var.name}/AgentMemory"
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_log_metric_filter" "memory_skips" {
  name           = "${var.name}-memory-skips"
  log_group_name = var.lambda_log_group_name
  pattern        = "MEMORY_SKIPPED"

  metric_transformation {
    name      = "MemorySkipCount"
    namespace = "${var.name}/AgentMemory"
    value     = "1"
    unit      = "Count"
  }
}

# ── Alarms ───────────────────────────────────────────────────────────────────

# Alarm 1: DLQ message count (stuck facts)
resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  alarm_name          = "${var.name}-dlq-messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "DLQ has messages — memory writes are failing silently"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = var.dlq_name
  }

  tags = { Name = "${var.name}-dlq-alarm" }
}

# Alarm 2: Lambda error rate
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.name}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Memory writer Lambda error rate is elevated"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.memory_writer_function_name
  }

  tags = { Name = "${var.name}-lambda-errors-alarm" }
}

# Alarm 3: Lambda p99 duration approaching timeout
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${var.name}-lambda-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  extended_statistic  = "p99"
  threshold           = 20000  # 20s (timeout is 30s)
  alarm_description   = "Memory writer p99 duration approaching 30s timeout"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.memory_writer_function_name
  }

  tags = { Name = "${var.name}-lambda-duration-alarm" }
}

# ── CloudWatch Dashboard ────────────────────────────────────────────────────

resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = var.name
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 8
        height = 6
        properties = {
          title   = "Lambda Invocations (Agent Activity Proxy)"
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", var.memory_writer_function_name, { stat = "Sum" }],
            ["AWS/Lambda", "Errors", "FunctionName", var.memory_writer_function_name, { stat = "Sum", color = "#d62728" }]
          ]
          period = 300
          region = var.aws_region
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 0
        width  = 8
        height = 6
        properties = {
          title   = "Memory Saves vs Skips (Quality Gate)"
          metrics = [
            ["${var.name}/AgentMemory", "MemorySaveCount", { stat = "Sum", color = "#2ca02c" }],
            ["${var.name}/AgentMemory", "MemorySkipCount", { stat = "Sum", color = "#d62728" }]
          ]
          period = 300
          region = var.aws_region
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 0
        width  = 8
        height = 6
        properties = {
          title   = "SQS Queue Depth + DLQ"
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", var.sqs_queue_name, { stat = "Sum" }],
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", var.dlq_name, { stat = "Sum", color = "#d62728" }]
          ]
          period = 300
          region = var.aws_region
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "Lambda Duration (p50, p99)"
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", var.memory_writer_function_name, { stat = "p50" }],
            ["AWS/Lambda", "Duration", "FunctionName", var.memory_writer_function_name, { stat = "p99", color = "#ff7f0e" }]
          ]
          period = 300
          region = var.aws_region
          view   = "timeSeries"
        }
      }
    ]
  })
}
