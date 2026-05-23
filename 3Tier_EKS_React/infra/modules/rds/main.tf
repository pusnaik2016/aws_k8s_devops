# =============================================================================
# RDS PostgreSQL Module
# Project: 3-Tier EKS Application
# Author: Pushparaj Naik
# Well-Architected: Security (encryption), Reliability (Multi-AZ, backups),
#                   Cost Optimization (auto-scaling storage)
# Compliance: GDPR (encryption at rest/transit), SOC2 (audit logging)
# =============================================================================

# --- RDS Private Subnets ---
resource "aws_subnet" "rds_1" {
  cidr_block        = "10.0.5.0/24"
  availability_zone = var.availability_zones[0]
  vpc_id            = var.vpc_id

  tags = {
    Name = "${var.prefix}-${var.environment}-rds-subnet-1"
  }
}

resource "aws_subnet" "rds_2" {
  cidr_block        = "10.0.6.0/24"
  availability_zone = var.availability_zones[1]
  vpc_id            = var.vpc_id

  tags = {
    Name = "${var.prefix}-${var.environment}-rds-subnet-2"
  }
}

# --- RDS Security Group (Principle of Least Privilege) ---
resource "aws_security_group" "rds" {
  name        = "${var.prefix}-${var.environment}-rds-sg"
  vpc_id      = var.vpc_id
  description = "Allow inbound PostgreSQL access from EKS private subnets only"

  # Well-Architected: Security - Restrict to EKS private subnets only
  ingress {
    protocol    = "tcp"
    from_port   = 5432
    to_port     = 5432
    cidr_blocks = ["10.0.3.0/24", "10.0.4.0/24"] # EKS private subnets only
    description = "PostgreSQL from EKS private subnets"
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${var.prefix}-${var.environment}-rds-sg"
  }
}

# --- RDS Instance with Well-Architected Best Practices ---
resource "aws_db_instance" "postgres" {
  identifier            = "${var.prefix}-${var.environment}-db"
  allocated_storage     = var.db_settings.allocated_storage
  max_allocated_storage = var.db_settings.max_allocated_storage
  engine                = "postgres"
  engine_version        = var.db_settings.engine_version
  instance_class        = var.db_settings.instance_class
  username              = var.db_settings.db_admin_username
  password              = random_password.dbs_random_string.result
  port                  = 5432
  publicly_accessible   = false
  db_subnet_group_name  = aws_db_subnet_group.postgres.id
  ca_cert_identifier    = var.db_settings.ca_cert_name

  # Well-Architected: Security - Encryption at rest
  storage_encrypted = true
  storage_type      = "gp3"
  kms_key_id        = aws_kms_key.env_kms.arn

  # Well-Architected: Reliability - Multi-AZ for production
  multi_az = var.environment == "prod" ? true : false

  # Well-Architected: Reliability - Backup and recovery
  backup_retention_period = var.db_settings.backup_retention_period
  backup_window           = "03:00-04:00" # UTC - low traffic window
  maintenance_window      = "sun:04:00-sun:05:00"

  # Compliance: Enable enhanced monitoring
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.rds_monitoring.arn
  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.env_kms.arn

  # Compliance: Enable audit logging
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  vpc_security_group_ids = [aws_security_group.rds.id]

  db_name                    = var.db_settings.db_name
  auto_minor_version_upgrade = true
  deletion_protection        = var.environment == "prod" ? true : false
  skip_final_snapshot        = var.environment == "prod" ? false : true
  final_snapshot_identifier  = var.environment == "prod" ? "${var.prefix}-${var.environment}-db-final" : null
  copy_tags_to_snapshot      = true

  tags = {
    Name        = "${var.prefix}-${var.environment}-db"
    Environment = var.environment
    DR          = var.enable_dr ? "enabled" : "disabled"
  }
}

# --- RDS Enhanced Monitoring IAM Role ---
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.prefix}-${var.environment}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# --- Secure Password Generation ---
resource "random_password" "dbs_random_string" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# --- AWS Secrets Manager (encrypted DB credentials) ---
resource "aws_secretsmanager_secret" "db_link" {
  name                    = "db/${var.prefix}-${var.environment}-db"
  description             = "Database connection string for ${var.prefix}-${var.environment}"
  kms_key_id              = aws_kms_key.env_kms.arn
  recovery_window_in_days = 7

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "dbs_secret_val" {
  secret_id = aws_secretsmanager_secret.db_link.id
  secret_string = jsonencode({
    connection_string = "postgresql://${var.db_settings.db_admin_username}:${random_password.dbs_random_string.result}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${aws_db_instance.postgres.db_name}"
    host              = aws_db_instance.postgres.address
    port              = aws_db_instance.postgres.port
    database          = aws_db_instance.postgres.db_name
    username          = var.db_settings.db_admin_username
    password          = random_password.dbs_random_string.result
  })

  lifecycle {
    create_before_destroy = true
  }
}

# --- RDS Subnet Group ---
resource "aws_db_subnet_group" "postgres" {
  name        = "${var.prefix}-${var.environment}-rds-db-subnet-group"
  description = "Subnet group for RDS instance"
  subnet_ids  = [aws_subnet.rds_1.id, aws_subnet.rds_2.id]

  tags = {
    Name        = "${var.prefix}-${var.environment}-db-subnet-group"
    Environment = var.environment
  }
}

# --- KMS Key for RDS and Secrets Manager ---
resource "aws_kms_key" "env_kms" {
  description             = "KMS key for RDS and Secrets Manager encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true # Compliance: Automatic key rotation

  tags = {
    Name        = "${var.prefix}-${var.environment}-rds-kms-key"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "env_kms_alias" {
  name          = "alias/${var.prefix}-${var.environment}-rds-kms-key"
  target_key_id = aws_kms_key.env_kms.id
}
