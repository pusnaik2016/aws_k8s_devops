# ══════════════════════════════════════════════════════════════════════════════
# Module: session-memory
# Lambda memory writer + DynamoDB audit trail + SQS queue (race-condition
# buffer) + S3 bucket for memory documents.
# ══════════════════════════════════════════════════════════════════════════════

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

# ── SQS Dead Letter Queue ───────────────────────────────────────────────────

resource "aws_sqs_queue" "dlq" {
  name                      = "${var.name}-memory-dlq"
  message_retention_seconds = 1209600  # 14 days

  tags = { Name = "${var.name}-memory-dlq" }
}

# ── SQS Queue (race-condition buffer for multi-agent setups) ─────────────────

resource "aws_sqs_queue" "memory_queue" {
  name                       = "${var.name}-memory-queue"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 86400  # 1 day

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })

  tags = { Name = "${var.name}-memory-queue" }
}

# ── DynamoDB Sessions Table ──────────────────────────────────────────────────

resource "aws_dynamodb_table" "sessions" {
  name         = "${var.name}-sessions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "session_id"
  range_key    = "timestamp_ms"

  attribute {
    name = "session_id"
    type = "S"
  }

  attribute {
    name = "timestamp_ms"
    type = "N"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = { Name = "${var.name}-sessions" }
}

# ── IAM Role for Memory Writer Lambda ────────────────────────────────────────

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
  name               = "${var.name}-memory-writer-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json

  tags = { Name = "${var.name}-memory-writer-role" }
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_services" {
  name = "${var.name}-memory-writer-services"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = "${var.memory_bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.sessions.arn
      },
      {
        Effect   = "Allow"
        Action   = ["bedrock-agent:StartIngestionJob"]
        Resource = var.knowledge_base_arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage"
        ]
        Resource = aws_sqs_queue.memory_queue.arn
      }
    ]
  })
}

# ── Lambda Function ──────────────────────────────────────────────────────────

data "archive_file" "memory_writer" {
  type        = "zip"
  source_dir  = var.lambda_source_dir
  output_path = "${path.module}/memory_writer.zip"
}

resource "aws_lambda_function" "memory_writer" {
  function_name    = "${var.name}-memory-writer"
  role             = aws_iam_role.lambda.arn
  handler          = "index.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 256

  filename         = data.archive_file.memory_writer.output_path
  source_code_hash = data.archive_file.memory_writer.output_base64sha256

  environment {
    variables = {
      MEMORY_BUCKET     = var.memory_bucket_name
      DYNAMODB_TABLE    = aws_dynamodb_table.sessions.name
      KNOWLEDGE_BASE_ID = var.knowledge_base_id
      DATA_SOURCE_ID    = var.data_source_id
      CONFIDENCE_THRESHOLD = tostring(var.confidence_threshold)
    }
  }

  tags = { Name = "${var.name}-memory-writer" }
}

# ── CloudWatch Log Group ────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.memory_writer.function_name}"
  retention_in_days = 30

  tags = { Name = "${var.name}-memory-writer-logs" }
}
