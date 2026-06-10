# ─────────────────────────────────────────────────────────────────────────────
# AWS Databases — Aurora Global (PostgreSQL), DynamoDB, ElastiCache
# ─────────────────────────────────────────────────────────────────────────────
# HIPAA/PCI-DSS compliant:
# - Aurora Global Database for transactional e-commerce data
# - DynamoDB for user sessions and shopping carts
# - ElastiCache Redis for caching layer
# - All encrypted with CMK, in isolated subnets
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }

  backend "s3" {
    bucket         = "medcloud-terraform-state"
    key            = "aws/databases/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "medcloud-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = merge(var.common_tags, {
      Cloud     = "AWS"
      Component = "databases"
    })
  }
}

# ─── Data Sources ────────────────────────────────────────────────────────────

data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "medcloud-terraform-state"
    key    = "aws/networking/terraform.tfstate"
    region = "us-east-1"
  }
}

# ─── Locals ──────────────────────────────────────────────────────────────────

locals {
  name_prefix     = "${var.project_name}-${var.environment}"
  vpc_id          = data.terraform_remote_state.networking.outputs.vpc_id
  isolated_subnets = data.terraform_remote_state.networking.outputs.isolated_subnet_ids
  private_subnets  = data.terraform_remote_state.networking.outputs.private_subnet_ids
}

# ─── KMS Key for Database Encryption ────────────────────────────────────────

resource "aws_kms_key" "database" {
  description             = "CMK for MedCloud database encryption (HIPAA)"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name       = "${local.name_prefix}-database-kms"
    Compliance = "HIPAA,PCI-DSS"
  }
}

resource "aws_kms_alias" "database" {
  name          = "alias/${local.name_prefix}-database"
  target_key_id = aws_kms_key.database.key_id
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Aurora Global Database (PostgreSQL) — E-Commerce Transactions
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

resource "aws_db_subnet_group" "aurora" {
  name       = "${local.name_prefix}-aurora-subnet-group"
  subnet_ids = local.isolated_subnets
  description = "Aurora subnet group — isolated subnets only (no internet)"

  tags = {
    Name = "${local.name_prefix}-aurora-subnet-group"
  }
}

resource "aws_security_group" "aurora" {
  name_prefix = "${local.name_prefix}-aurora-"
  description = "Aurora PostgreSQL security group"
  vpc_id      = local.vpc_id

  ingress {
    description = "PostgreSQL from private subnets (EKS)"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
  }

  ingress {
    description = "PostgreSQL from Azure (cross-cloud)"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.azure_vnet_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-aurora-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Aurora Global Cluster
resource "aws_rds_global_cluster" "main" {
  count = var.environment == "prod" ? 1 : 0

  global_cluster_identifier = "${local.name_prefix}-aurora-global"
  engine                    = "aurora-postgresql"
  engine_version            = "15.4"
  database_name             = "medcloud"
  storage_encrypted         = true
}

# Aurora Cluster (Primary)
resource "aws_rds_cluster" "primary" {
  cluster_identifier          = "${local.name_prefix}-aurora-primary"
  engine                      = "aurora-postgresql"
  engine_version              = "15.4"
  database_name               = "medcloud"
  master_username             = "medcloud_admin"
  manage_master_user_password = true # AWS Secrets Manager managed password
  global_cluster_identifier   = var.environment == "prod" ? aws_rds_global_cluster.main[0].id : null

  db_subnet_group_name   = aws_db_subnet_group.aurora.name
  vpc_security_group_ids = [aws_security_group.aurora.id]

  # HIPAA: Encryption at rest with CMK
  storage_encrypted = true
  kms_key_id        = aws_kms_key.database.arn

  # HIPAA: Enhanced monitoring and audit
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  backup_retention_period         = var.environment == "prod" ? 35 : 7
  preferred_backup_window         = "02:00-03:00"
  preferred_maintenance_window    = "sat:04:00-sat:05:00"
  copy_tags_to_snapshot           = true
  deletion_protection             = var.environment == "prod" ? true : false
  skip_final_snapshot             = var.environment == "prod" ? false : true
  final_snapshot_identifier       = var.environment == "prod" ? "${local.name_prefix}-aurora-final" : null

  # Performance Insights (HIPAA audit trail for queries)
  iam_database_authentication_enabled = true

  tags = {
    Name       = "${local.name_prefix}-aurora-primary"
    Compliance = "HIPAA,PCI-DSS"
    DataClass  = "PHI"
  }
}

# Aurora Instances
resource "aws_rds_cluster_instance" "primary" {
  count = var.environment == "prod" ? 2 : 1

  identifier           = "${local.name_prefix}-aurora-${count.index}"
  cluster_identifier   = aws_rds_cluster.primary.id
  instance_class       = var.environment == "prod" ? "db.r6g.xlarge" : "db.r6g.large"
  engine               = aws_rds_cluster.primary.engine
  engine_version       = aws_rds_cluster.primary.engine_version
  publicly_accessible  = false

  # Performance Insights
  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.database.arn

  # Enhanced Monitoring
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  tags = {
    Name = "${local.name_prefix}-aurora-instance-${count.index}"
  }
}

# RDS Enhanced Monitoring IAM Role
resource "aws_iam_role" "rds_monitoring" {
  name = "${local.name_prefix}-rds-monitoring-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DynamoDB — User Sessions & Shopping Carts
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

resource "aws_dynamodb_table" "user_sessions" {
  name         = "${local.name_prefix}-user-sessions"
  billing_mode = var.environment == "prod" ? "PROVISIONED" : "PAY_PER_REQUEST"
  hash_key     = "session_id"
  range_key    = "user_id"

  read_capacity  = var.environment == "prod" ? 100 : null
  write_capacity = var.environment == "prod" ? 50 : null

  attribute {
    name = "session_id"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  # HIPAA: Encryption with CMK
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.database.arn
  }

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = true
  }

  # Global table for multi-region (prod only)
  dynamic "replica" {
    for_each = var.environment == "prod" ? [var.aws_secondary_region] : []
    content {
      region_name = replica.value
      kms_key_arn = aws_kms_key.database.arn
    }
  }

  tags = {
    Name      = "${local.name_prefix}-user-sessions"
    DataClass = "PII"
  }
}

resource "aws_dynamodb_table" "shopping_cart" {
  name         = "${local.name_prefix}-shopping-cart"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "cart_id"
  range_key    = "product_id"

  attribute {
    name = "cart_id"
    type = "S"
  }

  attribute {
    name = "product_id"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.database.arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name      = "${local.name_prefix}-shopping-cart"
    DataClass = "PCI"
  }
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ElastiCache Redis — Caching Layer
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

resource "aws_elasticache_subnet_group" "main" {
  name       = "${local.name_prefix}-redis-subnet-group"
  subnet_ids = local.isolated_subnets
}

resource "aws_security_group" "redis" {
  name_prefix = "${local.name_prefix}-redis-"
  description = "ElastiCache Redis security group"
  vpc_id      = local.vpc_id

  ingress {
    description = "Redis from private subnets (EKS)"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-redis-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "${local.name_prefix}-redis"
  description          = "MedCloud Redis cache - HIPAA compliant"

  engine               = "redis"
  engine_version       = "7.1"
  node_type            = var.environment == "prod" ? "cache.r6g.large" : "cache.t4g.medium"
  num_cache_clusters   = var.environment == "prod" ? 3 : 1
  port                 = 6379

  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [aws_security_group.redis.id]

  # HIPAA: Encryption
  at_rest_encryption_enabled = true
  kms_key_id                 = aws_kms_key.database.arn
  transit_encryption_enabled = true
  auth_token                 = null # Use IAM auth instead

  # HA settings
  automatic_failover_enabled = var.environment == "prod" ? true : false
  multi_az_enabled           = var.environment == "prod" ? true : false

  # Maintenance
  snapshot_retention_limit = var.environment == "prod" ? 7 : 1
  snapshot_window          = "03:00-04:00"
  maintenance_window       = "sat:05:00-sat:06:00"

  tags = {
    Name = "${local.name_prefix}-redis"
  }
}

# ─── Outputs ─────────────────────────────────────────────────────────────────

output "aurora_cluster_endpoint" {
  description = "Aurora cluster writer endpoint"
  value       = aws_rds_cluster.primary.endpoint
}

output "aurora_reader_endpoint" {
  description = "Aurora cluster reader endpoint"
  value       = aws_rds_cluster.primary.reader_endpoint
}

output "dynamodb_sessions_table" {
  description = "DynamoDB user sessions table name"
  value       = aws_dynamodb_table.user_sessions.name
}

output "dynamodb_cart_table" {
  description = "DynamoDB shopping cart table name"
  value       = aws_dynamodb_table.shopping_cart.name
}

output "redis_endpoint" {
  description = "Redis primary endpoint"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
}
