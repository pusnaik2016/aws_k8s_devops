# ==============================================================================
# Aurora Global Database — Primary Cluster (us-east-1)
# ==============================================================================
# Writer instance in primary region with HA (writer + reader).
# Cross-region replication handled by Aurora Global Database.
# ==============================================================================

resource "aws_rds_global_cluster" "main" {
  global_cluster_identifier = var.aurora_global_cluster_id
  engine                    = "aurora-mysql"
  engine_version            = var.aurora_engine_version
  database_name             = "ecommercedb"
  storage_encrypted         = true
  deletion_protection       = true
}

# =============================================================================
# Aurora Cluster — Primary Writer
# =============================================================================
resource "aws_rds_cluster" "primary" {
  cluster_identifier        = "${var.project_name}-aurora"
  global_cluster_identifier = aws_rds_global_cluster.main.id
  engine                    = aws_rds_global_cluster.main.engine
  engine_version            = aws_rds_global_cluster.main.engine_version
  master_username           = var.aurora_master_username
  master_password           = var.aurora_master_password
  database_name             = "ecommercedb"

  db_subnet_group_name   = module.vpc.db_subnet_group_name
  vpc_security_group_ids = [module.security_groups.aurora_sg_id]

  # Encryption
  storage_encrypted = true
  kms_key_id        = module.kms.rds_key_arn

  # Backup
  backup_retention_period      = 35
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"
  copy_tags_to_snapshot        = true
  skip_final_snapshot          = false
  final_snapshot_identifier    = "${var.project_name}-aurora-final-snapshot"

  # Logging → CloudWatch
  enabled_cloudwatch_logs_exports = ["audit", "slowquery"]

  # Security
  iam_database_authentication_enabled = true
  deletion_protection                 = true

  tags = merge(local.common_tags, {
    Name     = "${var.project_name}-aurora-primary"
    Role     = "writer"
    DR_Tier  = "tier-1"
  })
}

# =============================================================================
# Aurora Instances — Writer + Reader for HA within region
# =============================================================================
resource "aws_rds_cluster_instance" "primary" {
  count = 2

  identifier         = "${var.project_name}-aurora-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.primary.id
  instance_class     = var.aurora_instance_class
  engine             = aws_rds_cluster.primary.engine
  engine_version     = aws_rds_cluster.primary.engine_version

  # Performance Insights (KMS-encrypted)
  performance_insights_enabled    = true
  performance_insights_kms_key_id = module.kms.rds_key_arn

  # Enhanced Monitoring
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  # Distribute across AZs for HA
  availability_zone = var.availability_zones[count.index % length(var.availability_zones)]

  auto_minor_version_upgrade = true
  publicly_accessible        = false

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-aurora-instance-${count.index + 1}"
    Role = count.index == 0 ? "writer" : "reader"
  })
}

# =============================================================================
# RDS Enhanced Monitoring IAM Role
# =============================================================================
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.project_name}-rds-enhanced-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-rds-monitoring-role"
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
  role       = aws_iam_role.rds_monitoring.name
}
