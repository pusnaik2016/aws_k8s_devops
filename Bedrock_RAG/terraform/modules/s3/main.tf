# -----------------------------------------------------------------------------
# S3 Bucket — Document storage for RAG knowledge base
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "documents" {
  bucket        = "${var.project_name}-documents-${var.environment}"
  force_destroy = var.environment != "prod"

  tags = { Name = "${var.project_name}-documents" }
}

resource "aws_s3_bucket_versioning" "documents" {
  bucket = aws_s3_bucket.documents.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "documents" {
  bucket = aws_s3_bucket.documents.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  rule {
    id     = "archive-old-documents"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }
  }
}

# Folder structure inside the bucket
resource "aws_s3_object" "folders" {
  for_each = toset(["documents/", "processed/", "embeddings/", "logs/"])

  bucket  = aws_s3_bucket.documents.id
  key     = each.value
  content = ""
}
