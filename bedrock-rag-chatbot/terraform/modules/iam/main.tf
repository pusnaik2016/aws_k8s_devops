# -----------------------------------------------------------------------------
# IAM Role — Lambda execution role with least-privilege access
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.project_name}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

# VPC access for Lambda (ENI management)
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Bedrock invocation policy — scoped to specific models
data "aws_iam_policy_document" "bedrock" {
  statement {
    sid    = "BedrockInvoke"
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream"
    ]
    resources = [
      "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.bedrock_model_id}",
      "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.embedding_model_id}"
    ]
  }

  statement {
    sid    = "BedrockGuardrails"
    effect = "Allow"
    actions = [
      "bedrock:ApplyGuardrail"
    ]
    resources = [
      "arn:aws:bedrock:${var.aws_region}:${var.account_id}:guardrail/*"
    ]
  }
}

resource "aws_iam_role_policy" "bedrock" {
  name   = "${var.project_name}-bedrock-access"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.bedrock.json
}

# S3 access — read documents, write processed results
data "aws_iam_policy_document" "s3" {
  statement {
    sid    = "S3ReadWrite"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
      "s3:DeleteObject"
    ]
    resources = [
      var.s3_bucket_arn,
      "${var.s3_bucket_arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "s3" {
  name   = "${var.project_name}-s3-access"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.s3.json
}

# OpenSearch Serverless access
data "aws_iam_policy_document" "opensearch" {
  statement {
    sid    = "OpenSearchAccess"
    effect = "Allow"
    actions = [
      "aoss:APIAccessAll"
    ]
    resources = [var.opensearch_arn]
  }
}

resource "aws_iam_role_policy" "opensearch" {
  name   = "${var.project_name}-opensearch-access"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.opensearch.json
}

# KMS access
data "aws_iam_policy_document" "kms" {
  statement {
    sid    = "KMSAccess"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey"
    ]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "kms" {
  name   = "${var.project_name}-kms-access"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.kms.json
}

# CloudWatch Logs
data "aws_iam_policy_document" "logs" {
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:${var.aws_region}:${var.account_id}:*"]
  }
}

resource "aws_iam_role_policy" "logs" {
  name   = "${var.project_name}-logs-access"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.logs.json
}
