###############################################################################
# EBS Cost Optimizer – Terraform
#
# Deploys a Lambda function (runs the Python tagger nightly via EventBridge)
# and an SNS topic for the cost-savings digest email.
###############################################################################

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  name_prefix = "ebs-cost-optimizer"
  common_tags = {
    Project     = local.name_prefix
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

###############################################################################
# IAM role for Lambda
###############################################################################

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${local.name_prefix}-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "lambda_permissions" {
  statement {
    sid    = "EBSReadTag"
    effect = "Allow"
    actions = [
      "ec2:DescribeVolumes",
      "ec2:DescribeInstances",
      "ec2:DescribeRegions",
      "ec2:DescribeSnapshots",
      "ec2:CreateTags",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "EBSCleanup"
    effect = "Allow"
    actions = [
      "ec2:CreateSnapshot",
      "ec2:DeleteVolume",
    ]
    # Restrict to volumes tagged by this tool to limit blast radius.
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/ManagedBy"
      values   = [local.name_prefix]
    }
  }

  statement {
    sid       = "SNSPublish"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.digest.arn]
  }

  statement {
    sid    = "Logs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_role_policy" "lambda" {
  name   = "${local.name_prefix}-policy"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_permissions.json
}

###############################################################################
# Package the Lambda deployment zip from the project source
###############################################################################

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../"
  excludes    = [
    ".venv",
    "__pycache__",
    "*.pyc",
    "tests",
    "reports",
    "terraform",
    ".git",
    "*.md",
    "*.toml",
    "*.txt",
    "config.yaml.example",
  ]
  output_path = "${path.module}/build/ebs_optimizer_lambda.zip"
}

###############################################################################
# Lambda function
###############################################################################

resource "aws_lambda_function" "tagger" {
  function_name    = "${local.name_prefix}-tagger"
  description      = "Nightly EBS volume tagger and cost-savings reporter."
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  role             = aws_iam_role.lambda.arn
  handler          = "lambda_handler.handler"
  runtime          = "python3.12"
  timeout          = 300
  memory_size      = 256

  environment {
    variables = {
      SNS_TOPIC_ARN   = aws_sns_topic.digest.arn
      CONFIG_YAML_B64 = var.config_yaml_base64
      DRY_RUN         = var.lambda_dry_run ? "true" : "false"
    }
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "tagger" {
  name              = "/aws/lambda/${aws_lambda_function.tagger.function_name}"
  retention_in_days = 14
  tags              = local.common_tags
}

###############################################################################
# EventBridge (CloudWatch Events) – nightly schedule
###############################################################################

resource "aws_cloudwatch_event_rule" "nightly" {
  name                = "${local.name_prefix}-nightly"
  description         = "Trigger EBS tagger every night at 02:00 UTC."
  schedule_expression = "cron(0 2 * * ? *)"
  tags                = local.common_tags
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.nightly.name
  target_id = "EBSTaggerLambda"
  arn       = aws_lambda_function.tagger.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tagger.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.nightly.arn
}

###############################################################################
# SNS – cost-savings digest email
###############################################################################

resource "aws_sns_topic" "digest" {
  name = "${local.name_prefix}-digest"
  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.digest.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
