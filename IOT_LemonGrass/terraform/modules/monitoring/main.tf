# -----------------------------------------------------------------------------
# Monitoring Module — CloudWatch Dashboard, Alarms, SNS
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# SNS Topic — Alert Notifications
# -----------------------------------------------------------------------------
resource "aws_sns_topic" "alerts" {
  name              = "${var.project_name}-iot-alerts"
  kms_master_key_id = var.kms_key_id

  tags = {
    Name = "${var.project_name}-iot-alerts"
  }
}

resource "aws_sns_topic_subscription" "email" {
  count = var.alert_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms
# -----------------------------------------------------------------------------

# Alarm: IoT Rule action failures
resource "aws_cloudwatch_metric_alarm" "rule_action_failure" {
  alarm_name          = "${var.project_name}-iot-rule-action-failure"
  alarm_description   = "IoT Rule Engine action failures detected"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Failure"
  namespace           = "AWS/IoT"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = {
    Name = "${var.project_name}-rule-failure-alarm"
  }
}

# Alarm: Lambda alert processor errors
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_name}-alert-processor-errors"
  alarm_description   = "Alert processor Lambda function errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 3
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  tags = {
    Name = "${var.project_name}-lambda-error-alarm"
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Dashboard — IoT Telemetry Overview
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_dashboard" "iot_overview" {
  dashboard_name = "${var.project_name}-iot-overview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "IoT Messages Published"
          metrics = [["AWS/IoT", "PublishIn.Success", { stat = "Sum", period = 300 }]]
          view    = "timeSeries"
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
          title = "IoT Rule Actions Executed"
          metrics = [
            ["AWS/IoT", "RuleMessageThrottled", { stat = "Sum", period = 300 }],
            ["AWS/IoT", "Failure", { stat = "Sum", period = 300 }],
            ["AWS/IoT", "Success", { stat = "Sum", period = 300 }]
          ]
          view   = "timeSeries"
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
          title = "Lambda Alert Processor"
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", var.lambda_function_name, { stat = "Sum", period = 300 }],
            ["AWS/Lambda", "Errors", "FunctionName", var.lambda_function_name, { stat = "Sum", period = 300 }],
            ["AWS/Lambda", "Duration", "FunctionName", var.lambda_function_name, { stat = "Average", period = 300 }]
          ]
          view   = "timeSeries"
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
          title   = "Connected Devices"
          metrics = [["AWS/IoT", "Connect.Success", { stat = "Sum", period = 300 }]]
          view    = "timeSeries"
          region  = var.aws_region
        }
      }
    ]
  })
}
