# -----------------------------------------------------------------------------
# Lambda Functions — Chat + Document Ingestion
# -----------------------------------------------------------------------------

# Package the Python application code
data "archive_file" "app_code" {
  type        = "zip"
  source_dir  = "${path.root}/../app"
  output_path = "${path.root}/../dist/app.zip"
}

# ----- Chat Lambda -----
resource "aws_lambda_function" "chat" {
  function_name    = "${var.project_name}-chat"
  role             = var.lambda_role_arn
  handler          = "lambda_handler.handler"
  runtime          = "python3.12"
  timeout          = 120
  memory_size      = 1024
  filename         = data.archive_file.app_code.output_path
  source_code_hash = data.archive_file.app_code.output_base64sha256

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_sg_id]
  }

  environment {
    variables = {
      S3_BUCKET_NAME       = var.s3_bucket_name
      OPENSEARCH_ENDPOINT  = var.opensearch_endpoint
      BEDROCK_MODEL_ID     = var.bedrock_model_id
      EMBEDDING_MODEL_ID   = var.embedding_model_id
      INDEX_NAME           = "rag-knowledge-base"
      ENVIRONMENT          = var.environment
      LOG_LEVEL            = var.environment == "prod" ? "INFO" : "DEBUG"
    }
  }

  kms_key_arn = var.kms_key_arn

  tracing_config {
    mode = "Active"
  }

  tags = { Name = "${var.project_name}-chat" }
}

resource "aws_cloudwatch_log_group" "chat" {
  name              = "/aws/lambda/${aws_lambda_function.chat.function_name}"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn
}

# ----- Ingest Lambda (triggered by S3 uploads) -----
resource "aws_lambda_function" "ingest" {
  function_name    = "${var.project_name}-ingest"
  role             = var.lambda_role_arn
  handler          = "ingest.handler.handler"
  runtime          = "python3.12"
  timeout          = 300
  memory_size      = 2048
  filename         = data.archive_file.app_code.output_path
  source_code_hash = data.archive_file.app_code.output_base64sha256

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_sg_id]
  }

  environment {
    variables = {
      OPENSEARCH_ENDPOINT = var.opensearch_endpoint
      EMBEDDING_MODEL_ID  = var.embedding_model_id
      INDEX_NAME          = "rag-knowledge-base"
      CHUNK_SIZE          = "512"
      CHUNK_OVERLAP       = "50"
      LOG_LEVEL           = "INFO"
    }
  }

  kms_key_arn = var.kms_key_arn

  tracing_config {
    mode = "Active"
  }

  tags = { Name = "${var.project_name}-ingest" }
}

resource "aws_cloudwatch_log_group" "ingest" {
  name              = "/aws/lambda/${aws_lambda_function.ingest.function_name}"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn
}

# S3 trigger for document ingestion
resource "aws_lambda_permission" "s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingest.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${var.s3_bucket_name}"
}

resource "aws_s3_bucket_notification" "document_upload" {
  bucket = var.s3_bucket_name

  lambda_function {
    lambda_function_arn = aws_lambda_function.ingest.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "documents/"
    filter_suffix       = ".pdf"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.ingest.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "documents/"
    filter_suffix       = ".txt"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.ingest.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "documents/"
    filter_suffix       = ".md"
  }

  depends_on = [aws_lambda_permission.s3_invoke]
}
