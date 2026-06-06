# -----------------------------------------------------------------------------
# IAM Module — Roles & Policies for IoT Greengrass PoC
# -----------------------------------------------------------------------------
# This module creates:
# 1. Greengrass Token Exchange Service (TES) Role
# 2. IoT Rules Engine Role (for S3, Timestream, Lambda actions)
# 3. Lambda Execution Role (for alert processor)
# 4. KMS Key for encryption
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# KMS Key — Shared encryption for all resources
# -----------------------------------------------------------------------------
resource "aws_kms_key" "main" {
  description             = "${var.project_name} encryption key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccountFullAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowIoTServiceUsage"
        Effect = "Allow"
        Principal = {
          Service = [
            "iot.amazonaws.com",
            "lambda.amazonaws.com",
            "s3.amazonaws.com",
            "logs.amazonaws.com"
          ]
        }
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-kms-key"
  }
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.project_name}"
  target_key_id = aws_kms_key.main.key_id
}

# -----------------------------------------------------------------------------
# 1. Greengrass Token Exchange Service (TES) Role
# Greengrass Core device assumes this role via credentials.iot.amazonaws.com
# to access AWS services (S3, CloudWatch, etc.)
# -----------------------------------------------------------------------------
resource "aws_iam_role" "greengrass_tes" {
  name = "${var.project_name}-greengrass-tes-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "credentials.iot.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.project_name}-greengrass-tes-role"
  }
}

resource "aws_iam_role_policy" "greengrass_tes_policy" {
  name = "${var.project_name}-greengrass-tes-policy"
  role = aws_iam_role.greengrass_tes.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3ComponentArtifacts"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.telemetry_bucket_arn,
          "${var.telemetry_bucket_arn}/*"
        ]
      },
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/greengrass/*"
      },
      {
        Sid    = "AllowKMSDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.main.arn
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# 2. IoT Rules Engine Role
# Used by IoT Rules to write to S3, Timestream, and invoke Lambda
# -----------------------------------------------------------------------------
resource "aws_iam_role" "iot_rules" {
  name = "${var.project_name}-iot-rules-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "iot.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.project_name}-iot-rules-role"
  }
}

resource "aws_iam_role_policy" "iot_rules_s3" {
  name = "${var.project_name}-iot-rules-s3"
  role = aws_iam_role.iot_rules.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3Write"
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${var.telemetry_bucket_arn}/*"
      },
      {
        Sid    = "AllowKMS"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.main.arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "iot_rules_timestream" {
  name = "${var.project_name}-iot-rules-timestream"
  role = aws_iam_role.iot_rules.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowTimestreamWrite"
      Effect = "Allow"
      Action = [
        "timestream:WriteRecords",
        "timestream:DescribeEndpoints"
      ]
      Resource = var.timestream_table_arn
    }]
  })
}

resource "aws_iam_role_policy" "iot_rules_lambda" {
  name = "${var.project_name}-iot-rules-lambda"
  role = aws_iam_role.iot_rules.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "AllowLambdaInvoke"
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = var.alert_lambda_arn
    }]
  })
}

# -----------------------------------------------------------------------------
# 3. Lambda Execution Role — Alert Processor
# -----------------------------------------------------------------------------
resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_name}-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.project_name}-lambda-exec-role"
  }
}

resource "aws_iam_role_policy" "lambda_exec_policy" {
  name = "${var.project_name}-lambda-exec-policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project_name}-*"
      },
      {
        Sid      = "AllowSNSPublish"
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = var.sns_topic_arn
      },
      {
        Sid    = "AllowKMSDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.main.arn
      }
    ]
  })
}
