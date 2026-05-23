# -----------------------------------------------------------------------------
# Lambda Module — Alert Processor Function
# -----------------------------------------------------------------------------
# Receives IoT Rules Engine threshold alerts, enriches the payload,
# and publishes to SNS for notification delivery.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Lambda Function — Alert Processor
# -----------------------------------------------------------------------------
data "archive_file" "alert_processor" {
  type        = "zip"
  source_dir  = "${path.module}/../../../lambda/alert_processor"
  output_path = "${path.module}/builds/alert_processor.zip"
}

resource "aws_lambda_function" "alert_processor" {
  function_name    = "${var.project_name}-alert-processor"
  description      = "Processes IoT threshold alerts and publishes to SNS"
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 128
  role             = var.lambda_exec_role_arn
  filename         = data.archive_file.alert_processor.output_path
  source_code_hash = data.archive_file.alert_processor.output_base64sha256

  environment {
    variables = {
      SNS_TOPIC_ARN = var.sns_topic_arn
      PROJECT_NAME  = var.project_name
      ENVIRONMENT   = var.environment
    }
  }

  tracing_config {
    mode = "Active"
  }

  dead_letter_config {
    target_arn = var.sns_topic_arn
  }

  tags = {
    Name = "${var.project_name}-alert-processor"
  }
}

# Allow IoT Rules Engine to invoke this Lambda
resource "aws_lambda_permission" "iot_invoke" {
  statement_id  = "AllowIoTRulesInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.alert_processor.function_name
  principal     = "iot.amazonaws.com"
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "alert_processor" {
  name              = "/aws/lambda/${aws_lambda_function.alert_processor.function_name}"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn

  tags = {
    Name = "${var.project_name}-alert-processor-logs"
  }
}
