###############################################################################
# Cost Analyzer Module — IAM Roles & Policies
###############################################################################

###############################################################################
# IAM Role — Cost Fetcher Lambda
###############################################################################

resource "aws_iam_role" "cost_fetcher" {
  name = "${local.prefix}-cost-fetcher-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Component = "cost_analyzer" }
}

# Basic Lambda execution: CloudWatch Logs
resource "aws_iam_role_policy_attachment" "cost_fetcher_basic" {
  role       = aws_iam_role.cost_fetcher.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Cost Explorer read access
# NOTE: ce:GetCostAndUsage always requires Resource: "*" — this is an AWS API constraint.
resource "aws_iam_role_policy" "cost_fetcher_ce" {
  name = "${local.prefix}-cost-fetcher-ce"
  role = aws_iam_role.cost_fetcher.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "CostExplorerRead"
        Effect   = "Allow"
        Action   = ["ce:GetCostAndUsage"]
        Resource = ["*"] # AWS API limitation — cannot be scoped further
      },
      {
        Sid    = "DynamoDBWrite"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
        ]
        Resource = [var.dynamodb_arn]
      }
    ]
  })
}

###############################################################################
# IAM Role — Anomaly Detector Lambda
###############################################################################

resource "aws_iam_role" "anomaly_detector" {
  name = "${local.prefix}-anomaly-detector-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Component = "cost_analyzer" }
}

# Basic Lambda execution: CloudWatch Logs
resource "aws_iam_role_policy_attachment" "anomaly_detector_basic" {
  role       = aws_iam_role.anomaly_detector.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "anomaly_detector_permissions" {
  name = "${local.prefix}-anomaly-detector-perms"
  role = aws_iam_role.anomaly_detector.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DynamoDBRead"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
        ]
        Resource = [var.dynamodb_arn]
      },
      {
        Sid    = "BedrockInvoke"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
        ]
        Resource = [
          "arn:aws:bedrock:${local.region}::foundation-model/${var.bedrock_model_id}",
        ]
      },
      {
        Sid      = "SNSPublish"
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = [var.sns_topic_arn]
      }
    ]
  })
}
