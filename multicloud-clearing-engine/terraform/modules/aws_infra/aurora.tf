# =============================================================================
# AWS Aurora PostgreSQL — Global Database
# =============================================================================
# Production Aurora cluster with:
#   - PostgreSQL 15.x engine
#   - CMK encryption at rest (HIPAA)
#   - 35-day backup retention
#   - Performance Insights for SOX audit
#   - IAM database authentication
#   - Deletion protection
# =============================================================================

# -----------------------------------------------------------------------------
# DB Subnet Group
# -----------------------------------------------------------------------------
resource "aws_db_subnet_group" "aurora" {
  name       = "${local.name_prefix}-aurora-subnet-group"
  subnet_ids = aws_subnet.private_data[*].id

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-aurora-subnet-group"
  })
}

# -----------------------------------------------------------------------------
# Aurora Security Group
# -----------------------------------------------------------------------------
resource "aws_security_group" "aurora" {
  name_prefix = "${local.name_prefix}-aurora-"
  vpc_id      = aws_vpc.main.id
  description = "Aurora PostgreSQL security group — allows access from EKS nodes only"

  ingress {
    description     = "PostgreSQL from EKS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
  }

  # Allow cross-cloud replication traffic via VPN
  ingress {
    description = "PostgreSQL from Azure VPN"
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

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-aurora-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Aurora Cluster Parameter Group
# -----------------------------------------------------------------------------
resource "aws_rds_cluster_parameter_group" "aurora" {
  name   = "${local.name_prefix}-aurora-params"
  family = "aurora-postgresql15"

  parameter {
    name         = "log_statement"
    value        = "all"
    apply_method = "immediate"
  }

  parameter {
    name         = "log_min_duration_statement"
    value        = "1000" # Log queries > 1 second
    apply_method = "immediate"
  }

  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements,pgaudit"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "pgaudit.log"
    value        = "all"
    apply_method = "immediate"
  }

  tags = local.tags
}

# -----------------------------------------------------------------------------
# Aurora Global Cluster
# -----------------------------------------------------------------------------
resource "aws_rds_global_cluster" "main" {
  global_cluster_identifier = "${local.name_prefix}-global"
  engine                    = "aurora-postgresql"
  engine_version            = "15.4"
  storage_encrypted         = true
  deletion_protection       = true
}

# -----------------------------------------------------------------------------
# Aurora Cluster (Primary Region)
# -----------------------------------------------------------------------------
resource "aws_rds_cluster" "aurora" {
  cluster_identifier          = "${local.name_prefix}-aurora"
  global_cluster_identifier   = aws_rds_global_cluster.main.id
  engine                      = "aurora-postgresql"
  engine_version              = "15.4"
  db_subnet_group_name        = aws_db_subnet_group.aurora.name
  vpc_security_group_ids      = [aws_security_group.aurora.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora.name

  # Encryption
  storage_encrypted = true
  kms_key_id        = aws_kms_key.main.arn

  # Backup & Recovery
  backup_retention_period      = 35  # HIPAA: extended retention
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"
  copy_tags_to_snapshot        = true
  deletion_protection          = true
  skip_final_snapshot          = false
  final_snapshot_identifier    = "${local.name_prefix}-aurora-final-snapshot"

  # IAM Authentication
  iam_database_authentication_enabled = true

  # Logging
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-aurora"
  })
}

# -----------------------------------------------------------------------------
# Aurora Instances
# -----------------------------------------------------------------------------
resource "aws_rds_cluster_instance" "writer" {
  identifier                   = "${local.name_prefix}-aurora-writer"
  cluster_identifier           = aws_rds_cluster.aurora.id
  instance_class               = var.aurora_instance_class
  engine                       = aws_rds_cluster.aurora.engine
  engine_version               = aws_rds_cluster.aurora.engine_version
  publicly_accessible          = false
  performance_insights_enabled = true  # SOX: query-level audit
  performance_insights_kms_key_id = aws_kms_key.main.arn
  performance_insights_retention_period = 731 # 2 years

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_enhanced_monitoring.arn

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-aurora-writer"
  })
}

resource "aws_rds_cluster_instance" "reader" {
  identifier                   = "${local.name_prefix}-aurora-reader"
  cluster_identifier           = aws_rds_cluster.aurora.id
  instance_class               = var.aurora_reader_instance_class
  engine                       = aws_rds_cluster.aurora.engine
  engine_version               = aws_rds_cluster.aurora.engine_version
  publicly_accessible          = false
  performance_insights_enabled = true
  performance_insights_kms_key_id = aws_kms_key.main.arn

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_enhanced_monitoring.arn

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-aurora-reader"
  })
}

# -----------------------------------------------------------------------------
# RDS Enhanced Monitoring Role
# -----------------------------------------------------------------------------
resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "${local.name_prefix}-rds-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
