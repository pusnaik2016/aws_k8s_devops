###############################################################################
# Cost Analyzer Module — Lambda Functions + EventBridge Schedulers
###############################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  prefix     = "cost-anomaly-${var.environment}"
}

###############################################################################
# Lambda deployment packages — zip the Python source files
###############################################################################

data "archive_file" "cost_fetcher" {
  type        = "zip"
  source_file = "${path.module}/lambda/cost_fetcher.py"
  output_path = "${path.module}/lambda/dist/cost_fetcher.zip"
}

data "archive_file" "anomaly_detector" {
  type        = "zip"
  source_file = "${path.module}/lambda/anomaly_detector.py"
  output_path = "${path.module}/lambda/dist/anomaly_detector.zip"
}

###############################################################################
# CloudWatch Log Groups (pre-create for explicit retention control)
###############################################################################

resource "aws_cloudwatch_log_group" "cost_fetcher" {
  name              = "/aws/lambda/${local.prefix}-cost-fetcher"
  retention_in_days = var.log_retention_days

  tags = {
    Component = "cost_analyzer"
    Lambda    = "cost-fetcher"
  }
}

resource "aws_cloudwatch_log_group" "anomaly_detector" {
  name              = "/aws/lambda/${local.prefix}-anomaly-detector"
  retention_in_days = var.log_retention_days

  tags = {
    Component = "cost_analyzer"
    Lambda    = "anomaly-detector"
  }
}

###############################################################################
# Lambda — Cost Fetcher
###############################################################################

resource "aws_lambda_function" "cost_fetcher" {
  function_name    = "${local.prefix}-cost-fetcher"
  description      = "Pulls 90-day cost history from Cost Explorer and stores in DynamoDB."
  filename         = data.archive_file.cost_fetcher.output_path
  source_code_hash = data.archive_file.cost_fetcher.output_base64sha256
  handler          = "cost_fetcher.lambda_handler"
  runtime          = "python3.12"
  role             = aws_iam_role.cost_fetcher.arn
  timeout          = 300
  memory_size      = 256

  environment {
    variables = {
      DYNAMODB_TABLE  = var.dynamodb_table
      RETENTION_DAYS  = tostring(var.retention_days)
      LOG_LEVEL       = var.log_level
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.cost_fetcher,
    aws_iam_role_policy_attachment.cost_fetcher_basic,
  ]

  tags = {
    Component = "cost_analyzer"
    Lambda    = "cost-fetcher"
  }
}

###############################################################################
# Lambda — Anomaly Detector
###############################################################################

resource "aws_lambda_function" "anomaly_detector" {
  function_name    = "${local.prefix}-anomaly-detector"
  description      = "Reads DynamoDB, calculates Z-scores, calls Bedrock, and sends SNS alerts."
  filename         = data.archive_file.anomaly_detector.output_path
  source_code_hash = data.archive_file.anomaly_detector.output_base64sha256
  handler          = "anomaly_detector.lambda_handler"
  runtime          = "python3.12"
  role             = aws_iam_role.anomaly_detector.arn
  timeout          = 600
  memory_size      = 512

  environment {
    variables = {
      DYNAMODB_TABLE   = var.dynamodb_table
      SNS_TOPIC_ARN    = var.sns_topic_arn
      BEDROCK_MODEL_ID = var.bedrock_model_id
      ZSCORE_THRESHOLD = tostring(var.zscore_threshold)
      MIN_HISTORY_DAYS = "14"
      AWS_REGION_NAME  = local.region
      LOG_LEVEL        = var.log_level
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.anomaly_detector,
    aws_iam_role_policy_attachment.anomaly_detector_basic,
  ]

  tags = {
    Component = "cost_analyzer"
    Lambda    = "anomaly-detector"
  }
}

###############################################################################
# EventBridge Scheduler — IAM role for invoking Lambdas
###############################################################################

resource "aws_iam_role" "scheduler" {
  name = "${local.prefix}-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Component = "cost_analyzer" }
}

resource "aws_iam_role_policy" "scheduler_invoke" {
  name = "${local.prefix}-scheduler-invoke"
  role = aws_iam_role.scheduler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = [
          aws_lambda_function.cost_fetcher.arn,
          aws_lambda_function.anomaly_detector.arn,
        ]
      }
    ]
  })
}

###############################################################################
# EventBridge Scheduler — Cost Fetcher (08:00 UTC daily)
###############################################################################

resource "aws_scheduler_schedule" "cost_fetcher" {
  name                         = "${local.prefix}-cost-fetcher"
  description                  = "Triggers Cost Fetcher Lambda daily at 08:00 UTC."
  schedule_expression          = var.fetcher_schedule
  schedule_expression_timezone = "UTC"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.cost_fetcher.arn
    role_arn = aws_iam_role.scheduler.arn

    retry_policy {
      maximum_retry_attempts       = 3
      maximum_event_age_in_seconds = 3600
    }
  }
}

###############################################################################
# EventBridge Scheduler — Anomaly Detector (08:10 UTC daily)
###############################################################################

resource "aws_scheduler_schedule" "anomaly_detector" {
  name                         = "${local.prefix}-anomaly-detector"
  description                  = "Triggers Anomaly Detector Lambda daily at 08:10 UTC (10 min after fetcher)."
  schedule_expression          = var.detector_schedule
  schedule_expression_timezone = "UTC"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.anomaly_detector.arn
    role_arn = aws_iam_role.scheduler.arn

    retry_policy {
      maximum_retry_attempts       = 3
      maximum_event_age_in_seconds = 3600
    }
  }
}
