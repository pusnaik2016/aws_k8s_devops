# ─────────────────────────────────────────────────────────────
# Aurora PostgreSQL — Serverless v2 + pgvector
# ─────────────────────────────────────────────────────────────
# Uses Serverless v2 for cost optimization (scales to zero ACUs)
# pgvector extension enabled for RAG vector embeddings storage.
# ─────────────────────────────────────────────────────────────

locals {
  common_tags = merge(var.tags, {
    Module      = "database"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

resource "aws_db_subnet_group" "aurora" {
  name       = "${var.project_name}-${var.environment}-aurora-subnet"
  subnet_ids = var.private_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-aurora-subnet-group"
  })
}

resource "aws_rds_cluster_parameter_group" "aurora" {
  family      = "aurora-postgresql15"
  name        = "${var.project_name}-${var.environment}-aurora-params"
  description = "Aurora PostgreSQL parameters with pgvector support"

  # Enable pgvector extension
  parameter {
    name         = "shared_preload_libraries"
    value        = "pgvector"
    apply_method = "pending-reboot"
  }

  # Performance tuning
  parameter {
    name  = "log_min_duration_statement"
    value = "1000"  # Log queries taking > 1 second
  }

  tags = local.common_tags
}

data "aws_ssm_parameter" "aurora_password" {
  name = "/${var.project_name}/${var.environment}/aurora/master-password"
}

resource "aws_rds_cluster" "main" {
  cluster_identifier = "${var.project_name}-${var.environment}-aurora"
  engine             = "aurora-postgresql"
  engine_mode        = "provisioned"
  engine_version     = var.aurora_engine_version
  database_name      = "omnipresense"

  master_username = var.aurora_master_username
  master_password = data.aws_ssm_parameter.aurora_password.value

  db_subnet_group_name            = aws_db_subnet_group.aurora.name
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora.name
  vpc_security_group_ids          = [var.aurora_security_group_id]

  storage_encrypted = true
  kms_key_id        = var.kms_aurora_key_arn

  backup_retention_period      = 7
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"
  deletion_protection          = var.environment == "prod" ? true : false
  skip_final_snapshot          = var.environment == "prod" ? false : true
  final_snapshot_identifier    = var.environment == "prod" ? "${var.project_name}-${var.environment}-final-snapshot" : null

  enabled_cloudwatch_logs_exports = ["postgresql"]

  serverlessv2_scaling_configuration {
    min_capacity = var.aurora_min_capacity
    max_capacity = var.aurora_max_capacity
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-aurora"
  })
}

resource "aws_rds_cluster_instance" "main" {
  count = 2  # Writer + Reader for HA

  identifier         = "${var.project_name}-${var.environment}-aurora-${count.index}"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-aurora-instance-${count.index}"
  })
}

# Enhanced Monitoring IAM Role
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.project_name}-${var.environment}-rds-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = { Service = "monitoring.rds.amazonaws.com" }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
