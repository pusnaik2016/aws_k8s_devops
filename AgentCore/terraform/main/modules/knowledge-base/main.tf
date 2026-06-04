# ══════════════════════════════════════════════════════════════════════════════
# Module: knowledge-base
# Bedrock Knowledge Base backed by Aurora pgvector with HIERARCHICAL chunking.
# ══════════════════════════════════════════════════════════════════════════════

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

# ── S3 Data Source Bucket ────────────────────────────────────────────────────

resource "aws_s3_bucket" "memory_docs" {
  bucket = "${var.name}-docs-${local.account_id}"

  tags = { Name = "${var.name}-docs" }
}

resource "aws_s3_bucket_versioning" "memory_docs" {
  bucket = aws_s3_bucket.memory_docs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "memory_docs" {
  bucket = aws_s3_bucket.memory_docs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "memory_docs" {
  bucket                  = aws_s3_bucket.memory_docs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── IAM Role for Bedrock Knowledge Base ──────────────────────────────────────

data "aws_iam_policy_document" "kb_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_iam_role" "kb" {
  name               = "${var.name}-kb-role"
  assume_role_policy = data.aws_iam_policy_document.kb_assume.json

  tags = { Name = "${var.name}-kb-role" }
}

resource "aws_iam_role_policy" "kb_s3" {
  name = "${var.name}-kb-s3"
  role = aws_iam_role.kb.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.memory_docs.arn,
          "${aws_s3_bucket.memory_docs.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "kb_bedrock" {
  name = "${var.name}-kb-bedrock"
  role = aws_iam_role.kb.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "arn:aws:bedrock:${local.region}::foundation-model/${var.embedding_model}"
      }
    ]
  })
}

resource "aws_iam_role_policy" "kb_rds" {
  name = "${var.name}-kb-rds"
  role = aws_iam_role.kb.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds-data:ExecuteStatement",
          "rds-data:BatchExecuteStatement"
        ]
        Resource = var.aurora_cluster_arn
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = var.aurora_secret_arn
      }
    ]
  })
}

# ── Bedrock Knowledge Base ───────────────────────────────────────────────────

resource "aws_bedrockagent_knowledge_base" "this" {
  name     = var.name
  role_arn = aws_iam_role.kb.arn

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:${local.region}::foundation-model/${var.embedding_model}"
    }
  }

  storage_configuration {
    type = "RDS"
    rds_configuration {
      resource_arn           = var.aurora_cluster_arn
      credentials_secret_arn = var.aurora_secret_arn
      database_name          = var.aurora_database_name
      table_name             = "bedrock_integration.bedrock_kb"

      field_mapping {
        primary_key_field = "id"
        vector_field      = "embedding"
        text_field        = "chunks"
        metadata_field    = "metadata"
      }
    }
  }

  tags = { Name = var.name }
}

# ── Data Source (S3) ─────────────────────────────────────────────────────────

resource "aws_bedrockagent_data_source" "this" {
  knowledge_base_id = aws_bedrockagent_knowledge_base.this.id
  name              = "${var.name}-s3-source"

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn              = aws_s3_bucket.memory_docs.arn
      inclusion_prefixes      = ["memories/"]
    }
  }

  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = "HIERARCHICAL"
      hierarchical_chunking_configuration {
        level_configuration {
          max_tokens = 1500  # parent chunk
        }
        level_configuration {
          max_tokens = 300   # child chunk (searched)
        }
        overlap_tokens = 60
      }
    }
  }
}
