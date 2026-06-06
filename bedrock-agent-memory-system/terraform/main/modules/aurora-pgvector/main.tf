# ══════════════════════════════════════════════════════════════════════════════
# Module: aurora-pgvector
# Aurora Serverless v2 cluster with the pgvector extension, configured as the
# vector store for Bedrock Knowledge Base.
# ══════════════════════════════════════════════════════════════════════════════

# ── VPC for Aurora ───────────────────────────────────────────────────────────

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "${var.name}-vpc" }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = { Name = "${var.name}-private-${count.index}" }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db-subnet"
  subnet_ids = aws_subnet.private[*].id

  tags = { Name = "${var.name}-db-subnet" }
}

# ── Security Group ───────────────────────────────────────────────────────────

resource "aws_security_group" "aurora" {
  name_prefix = "${var.name}-aurora-"
  vpc_id      = aws_vpc.this.id
  description = "Allow PostgreSQL access from Bedrock and Lambda"

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "PostgreSQL from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = { Name = "${var.name}-aurora-sg" }

  lifecycle {
    create_before_destroy = true
  }
}

# ── Aurora Serverless v2 Cluster ─────────────────────────────────────────────

resource "aws_rds_cluster" "this" {
  cluster_identifier   = var.name
  engine               = "aurora-postgresql"
  engine_version       = "15.17"
  engine_mode          = "provisioned"
  database_name        = "agentcore"
  master_username      = var.master_username
  master_password      = var.master_password
  db_subnet_group_name = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.aurora.id]

  # Required for Bedrock KB — uses RDS Data API for vector queries
  enable_http_endpoint = true

  serverlessv2_scaling_configuration {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }

  storage_encrypted = true
  skip_final_snapshot = var.skip_final_snapshot

  tags = { Name = var.name }
}

resource "aws_rds_cluster_instance" "this" {
  cluster_identifier = aws_rds_cluster.this.id
  identifier         = "${var.name}-instance-1"
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version

  tags = { Name = "${var.name}-instance-1" }
}

# ── DB Init Lambda (bootstraps pgvector schema) ─────────────────────────────

data "aws_iam_policy_document" "db_init_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "db_init" {
  name               = "${var.name}-db-init-role"
  assume_role_policy = data.aws_iam_policy_document.db_init_assume.json
}

resource "aws_iam_role_policy_attachment" "db_init_basic" {
  role       = aws_iam_role.db_init.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "db_init_rds" {
  name = "${var.name}-db-init-rds"
  role = aws_iam_role.db_init.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds-data:ExecuteStatement",
          "rds-data:BatchExecuteStatement"
        ]
        Resource = aws_rds_cluster.this.arn
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "*"
      }
    ]
  })
}

# The db_init Lambda creates the pgvector extension and schema
# that Bedrock Knowledge Base expects.
resource "aws_lambda_function" "db_init" {
  function_name = "${var.name}-db-init"
  role          = aws_iam_role.db_init.arn
  handler       = "index.handler"
  runtime       = "python3.12"
  timeout       = 60

  filename         = data.archive_file.db_init.output_path
  source_code_hash = data.archive_file.db_init.output_base64sha256

  environment {
    variables = {
      CLUSTER_ARN = aws_rds_cluster.this.arn
      SECRET_ARN  = aws_rds_cluster.this.master_user_secret[0].secret_arn
      DB_NAME     = "agentcore"
    }
  }

  tags = { Name = "${var.name}-db-init" }

  depends_on = [aws_rds_cluster_instance.this]
}

# Inline Lambda code for DB init
data "archive_file" "db_init" {
  type        = "zip"
  output_path = "${path.module}/db_init.zip"

  source {
    content  = <<-PYTHON
import json
import os
import boto3

rds_data = boto3.client("rds-data")

SQL_STATEMENTS = [
    "CREATE EXTENSION IF NOT EXISTS vector;",
    "CREATE SCHEMA IF NOT EXISTS bedrock_integration;",
    """CREATE TABLE IF NOT EXISTS bedrock_integration.bedrock_kb (
        id        uuid PRIMARY KEY,
        embedding vector(1536),
        chunks    text,
        metadata  json
    );""",
    """CREATE INDEX IF NOT EXISTS bedrock_kb_embedding_idx
        ON bedrock_integration.bedrock_kb
        USING hnsw (embedding vector_cosine_ops);"""
]

def handler(event, context):
    cluster_arn = os.environ["CLUSTER_ARN"]
    secret_arn  = os.environ["SECRET_ARN"]
    db_name     = os.environ["DB_NAME"]

    results = []
    for sql in SQL_STATEMENTS:
        try:
            rds_data.execute_statement(
                resourceArn=cluster_arn,
                secretArn=secret_arn,
                database=db_name,
                sql=sql
            )
            results.append({"sql": sql[:60], "status": "OK"})
        except Exception as e:
            results.append({"sql": sql[:60], "status": str(e)})

    return {"statusCode": 200, "body": json.dumps(results)}
PYTHON
    filename = "index.py"
  }
}

# Invoke the init Lambda once after creation
resource "aws_lambda_invocation" "db_init" {
  function_name = aws_lambda_function.db_init.function_name
  input         = jsonencode({})

  depends_on = [aws_lambda_function.db_init]

  lifecycle {
    replace_triggered_by = [aws_lambda_function.db_init]
  }
}
