# ==============================================================================
# Aurora Global Database — Secondary Cluster (ap-south-1)
# ==============================================================================
# Read-only replica that can be promoted to writer during DR failover.
# The global_cluster_identifier links it to the primary in us-east-1.
# ==============================================================================

resource "aws_rds_cluster" "secondary" {
  cluster_identifier        = "${var.project_name}-aurora-secondary"
  global_cluster_identifier = var.aurora_global_cluster_id
  engine                    = "aurora-mysql"
  engine_version            = var.aurora_engine_version

  # No master credentials needed — inherited from global cluster
  db_subnet_group_name   = module.vpc.db_subnet_group_name
  vpc_security_group_ids = [module.security_groups.aurora_sg_id]

  storage_encrypted = true
  kms_key_id        = module.kms.rds_key_arn

  backup_retention_period      = 35
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"
  copy_tags_to_snapshot        = true
  skip_final_snapshot          = true

  enabled_cloudwatch_logs_exports = ["audit", "slowquery"]

  deletion_protection = true

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-aurora-secondary"
    Role    = "reader"
    DR_Tier = "tier-1"
  })

  lifecycle {
    ignore_changes = [
      replication_source_identifier  # Managed by Aurora Global DB
    ]
  }
}

# Aurora Reader Instance(s) in secondary region
resource "aws_rds_cluster_instance" "secondary" {
  count = 2

  identifier         = "${var.project_name}-aurora-secondary-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.secondary.id
  instance_class     = var.aurora_instance_class
  engine             = aws_rds_cluster.secondary.engine
  engine_version     = aws_rds_cluster.secondary.engine_version

  performance_insights_enabled    = true
  performance_insights_kms_key_id = module.kms.rds_key_arn

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  availability_zone          = var.availability_zones[count.index % length(var.availability_zones)]
  auto_minor_version_upgrade = true
  publicly_accessible        = false

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-aurora-secondary-${count.index + 1}"
    Role = "reader"
  })
}

resource "aws_iam_role" "rds_monitoring" {
  name = "${var.project_name}-rds-monitoring-secondary"
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
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
  role       = aws_iam_role.rds_monitoring.name
}
