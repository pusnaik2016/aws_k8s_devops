# ============================================================================
# AWS Databases — Aurora PostgreSQL Global, DynamoDB, ElastiCache
# ============================================================================

terraform {
  required_version = ">= 1.5"
}

# ──────────────────────────────────────────────────────────────────────────────
# Aurora PostgreSQL Global Database (Primary Writer)
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_rds_global_cluster" "main" {
  global_cluster_identifier = "${var.project}-${var.environment}-global-db"
  engine                    = "aurora-postgresql"
  engine_version            = "16.1"
  database_name             = "healthcloud"
  storage_encrypted         = true
  deletion_protection       = var.environment == "prod" ? true : false
}

resource "aws_db_subnet_group" "aurora" {
  name       = "${var.project}-${var.environment}-aurora-subnet-group"
  subnet_ids = var.database_subnet_ids

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-aurora-subnet-group"
  })
}

resource "aws_rds_cluster" "primary" {
  cluster_identifier        = "${var.project}-${var.environment}-aurora-primary"
  global_cluster_identifier = aws_rds_global_cluster.main.id
  engine                    = "aurora-postgresql"
  engine_version            = "16.1"
  master_username           = var.db_master_username
  master_password           = var.db_master_password
  db_subnet_group_name      = aws_db_subnet_group.aurora.name
  vpc_security_group_ids    = [aws_security_group.aurora.id]
  kms_key_id                = var.kms_key_arn
  storage_encrypted         = true
  backup_retention_period   = var.environment == "prod" ? 35 : 7
  preferred_backup_window   = "03:00-04:00"
  deletion_protection       = var.environment == "prod" ? true : false
  copy_tags_to_snapshot     = true
  iam_database_authentication_enabled = true

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = merge(var.common_tags, {
    Name               = "${var.project}-${var.environment}-aurora-primary"
    DataClassification = "phi"
    Compliance         = "hipaa"
  })
}

resource "aws_rds_cluster_instance" "primary" {
  count                = var.environment == "prod" ? 3 : 1
  identifier           = "${var.project}-${var.environment}-aurora-instance-${count.index}"
  cluster_identifier   = aws_rds_cluster.primary.id
  instance_class       = var.environment == "prod" ? "db.r6g.xlarge" : "db.r6g.large"
  engine               = "aurora-postgresql"
  publicly_accessible  = false
  performance_insights_enabled    = true
  performance_insights_kms_key_id = var.kms_key_arn

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-aurora-instance-${count.index}"
  })
}

resource "aws_security_group" "aurora" {
  name_prefix = "${var.project}-${var.environment}-aurora-"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_sg_id]
    description     = "PostgreSQL from EKS"
  }

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-aurora-sg"
  })
}

# ──────────────────────────────────────────────────────────────────────────────
# DynamoDB Global Table (for session/cache)
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_dynamodb_table" "sessions" {
  name         = "${var.project}-${var.environment}-sessions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "session_id"
  range_key    = "created_at"

  attribute {
    name = "session_id"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "N"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  point_in_time_recovery {
    enabled = true
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = merge(var.common_tags, {
    Name               = "${var.project}-${var.environment}-sessions"
    DataClassification = "internal"
  })
}

# ──────────────────────────────────────────────────────────────────────────────
# ElastiCache Redis (application caching)
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.project}-${var.environment}-redis-subnet"
  subnet_ids = var.database_subnet_ids
}

resource "aws_security_group" "redis" {
  name_prefix = "${var.project}-${var.environment}-redis-"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [var.eks_sg_id]
    description     = "Redis from EKS"
  }

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-redis-sg"
  })
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${var.project}-${var.environment}-redis"
  description          = "HealthCloud Redis cache"
  engine               = "redis"
  engine_version       = "7.1"
  node_type            = var.environment == "prod" ? "cache.r6g.large" : "cache.r6g.medium"
  num_cache_clusters   = var.environment == "prod" ? 3 : 1
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [aws_security_group.redis.id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  kms_key_id                 = var.kms_key_arn
  auth_token                 = var.redis_auth_token
  automatic_failover_enabled = var.environment == "prod" ? true : false
  multi_az_enabled           = var.environment == "prod" ? true : false

  snapshot_retention_limit = var.environment == "prod" ? 7 : 1
  snapshot_window          = "04:00-05:00"

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-redis"
  })
}
