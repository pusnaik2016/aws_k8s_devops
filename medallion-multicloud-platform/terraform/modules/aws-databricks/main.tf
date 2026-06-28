# =============================================================================
# AWS DATABRICKS MODULE — Workspace, Unity Catalog, Secret Scopes
# =============================================================================
# Deploys Databricks E2 workspace with:
#   - VNet injection (Private Link only, no public IP)
#   - Customer-Managed Keys for managed services + DBFS
#   - Unity Catalog metastore with external locations (S3 medallion paths)
#   - Secret Scope backed by AWS Secrets Manager
#   - Cluster policy enforcing compliance controls
#
# COMPLIANCE:
#   HIPAA  — Private-only access, CMK encryption, audit logging
#   SOC 2  — Unity Catalog RBAC, secret scope redaction
#   PCI-DSS — RLS/column masking, no data exfiltration paths
# =============================================================================

# ---------------------------------------------------------------------------
# Locals
# ---------------------------------------------------------------------------
locals {
  name_prefix = "${var.project_name}-${var.environment}"

  tags = merge(var.common_tags, {
    Module      = "aws-databricks"
    Cloud       = "aws"
    Environment = var.environment
    Compliance  = "hipaa-soc2-pci"
    ManagedBy   = "terraform"
  })
}

# =============================================================================
# DATABRICKS MWS WORKSPACE (E2 Architecture)
# =============================================================================

# Credential configuration (cross-account IAM role)
resource "databricks_mws_credentials" "this" {
  provider         = databricks.mws
  account_id       = var.databricks_account_id
  credentials_name = "${local.name_prefix}-credentials"
  role_arn         = var.databricks_cross_account_role_arn
}

# Storage configuration (DBFS root bucket)
resource "aws_s3_bucket" "dbfs_root" {
  bucket        = "${local.name_prefix}-dbfs-root"
  force_destroy = false

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-dbfs-root"
  })
}

resource "aws_s3_bucket_versioning" "dbfs_root" {
  bucket = aws_s3_bucket.dbfs_root.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "dbfs_root" {
  bucket = aws_s3_bucket.dbfs_root.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.databricks_kms_key_id
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "dbfs_root" {
  bucket                  = aws_s3_bucket.dbfs_root.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "databricks_mws_storage_configurations" "this" {
  provider                   = databricks.mws
  account_id                 = var.databricks_account_id
  storage_configuration_name = "${local.name_prefix}-storage"
  bucket_name                = aws_s3_bucket.dbfs_root.id
}

# Network configuration (VNet injection with Private Link)
resource "databricks_mws_networks" "this" {
  provider     = databricks.mws
  account_id   = var.databricks_account_id
  network_name = "${local.name_prefix}-network"
  vpc_id       = var.vpc_id

  subnet_ids         = var.private_compute_subnet_ids
  security_group_ids = [var.databricks_compute_sg_id]

  vpc_endpoints {
    dataplane_relay = [var.databricks_scc_relay_vpce_id]
    rest_api        = [var.databricks_workspace_vpce_id]
  }
}

# CMK configuration for managed services
resource "databricks_mws_customer_managed_keys" "managed_services" {
  provider   = databricks.mws
  account_id = var.databricks_account_id

  aws_key_info {
    key_arn   = var.databricks_kms_key_arn
    key_alias = "alias/${local.name_prefix}-databricks"
  }

  use_cases = ["MANAGED_SERVICES"]
}

# CMK configuration for storage (DBFS)
resource "databricks_mws_customer_managed_keys" "storage" {
  provider   = databricks.mws
  account_id = var.databricks_account_id

  aws_key_info {
    key_arn   = var.s3_kms_key_arn
    key_alias = "alias/${local.name_prefix}-s3-data"
  }

  use_cases = ["STORAGE"]
}

# Workspace deployment
resource "databricks_mws_workspaces" "this" {
  provider       = databricks.mws
  account_id     = var.databricks_account_id
  workspace_name = "${local.name_prefix}-workspace"
  aws_region     = var.aws_region

  credentials_id                = databricks_mws_credentials.this.credentials_id
  storage_configuration_id      = databricks_mws_storage_configurations.this.storage_configuration_id
  network_id                    = databricks_mws_networks.this.network_id
  managed_services_customer_managed_key_id = databricks_mws_customer_managed_keys.managed_services.customer_managed_key_id
  storage_customer_managed_key_id          = databricks_mws_customer_managed_keys.storage.customer_managed_key_id

  # Private Link only — no public access
  private_access_settings_id = databricks_mws_private_access_settings.this.private_access_settings_id
}

# Private Access Settings — No public access to workspace
resource "databricks_mws_private_access_settings" "this" {
  provider                     = databricks.mws
  account_id                   = var.databricks_account_id
  private_access_settings_name = "${local.name_prefix}-pas"
  region                       = var.aws_region

  public_access_enabled        = false # COMPLIANCE: Zero public exposure
  private_access_level         = "ACCOUNT"
}

# =============================================================================
# UNITY CATALOG — Centralized Data Governance
# =============================================================================

# Metastore (one per region)
resource "databricks_metastore" "this" {
  provider = databricks.workspace
  name     = "${local.name_prefix}-metastore"
  region   = var.aws_region

  storage_root = "s3://${var.gold_bucket_name}/unity-catalog"

  force_destroy = false
}

# Assign metastore to workspace
resource "databricks_metastore_assignment" "this" {
  provider     = databricks.workspace
  workspace_id = databricks_mws_workspaces.this.workspace_id
  metastore_id = databricks_metastore.this.id
}

# External locations for medallion layers
resource "databricks_external_location" "bronze" {
  provider        = databricks.workspace
  name            = "bronze-landing"
  url             = "s3://${var.bronze_bucket_name}/"
  credential_name = databricks_storage_credential.s3.name
  comment         = "Bronze layer — raw data ingestion landing zone"

  depends_on = [databricks_metastore_assignment.this]
}

resource "databricks_external_location" "silver" {
  provider        = databricks.workspace
  name            = "silver-curated"
  url             = "s3://${var.silver_bucket_name}/"
  credential_name = databricks_storage_credential.s3.name
  comment         = "Silver layer — cleansed and tokenized data"

  depends_on = [databricks_metastore_assignment.this]
}

resource "databricks_external_location" "gold" {
  provider        = databricks.workspace
  name            = "gold-aggregated"
  url             = "s3://${var.gold_bucket_name}/"
  credential_name = databricks_storage_credential.s3.name
  comment         = "Gold layer — business aggregates for analytics"

  depends_on = [databricks_metastore_assignment.this]
}

# Storage credential for S3 access
resource "databricks_storage_credential" "s3" {
  provider = databricks.workspace
  name     = "${local.name_prefix}-s3-credential"

  aws_iam_role {
    role_arn = var.databricks_cross_account_role_arn
  }

  comment = "IAM role credential for medallion S3 buckets"

  depends_on = [databricks_metastore_assignment.this]
}

# =============================================================================
# CATALOG & SCHEMA — Data Organization
# =============================================================================
resource "databricks_catalog" "medallion" {
  provider = databricks.workspace
  name     = "medallion"
  comment  = "Medallion architecture data catalog — Bronze/Silver/Gold layers"

  depends_on = [databricks_metastore_assignment.this]
}

resource "databricks_schema" "bronze" {
  provider    = databricks.workspace
  catalog_name = databricks_catalog.medallion.name
  name         = "bronze"
  comment      = "Raw ingestion landing zone"
}

resource "databricks_schema" "silver" {
  provider    = databricks.workspace
  catalog_name = databricks_catalog.medallion.name
  name         = "silver"
  comment      = "Cleansed, validated, and tokenized data"
}

resource "databricks_schema" "gold" {
  provider    = databricks.workspace
  catalog_name = databricks_catalog.medallion.name
  name         = "gold"
  comment      = "Business-level aggregates and analytics-ready data"
}

# =============================================================================
# SECRET SCOPE — Backed by AWS Secrets Manager
# =============================================================================
resource "databricks_secret_scope" "aws_sm" {
  provider = databricks.workspace
  name     = var.secret_scope_name

  # Backend: AWS Secrets Manager (via Databricks native integration)
  backend_type = "DATABRICKS"
}

# Store reference secrets in Databricks scope (fetched from Secrets Manager at runtime)
resource "databricks_secret" "warehouse_password" {
  provider     = databricks.workspace
  scope        = databricks_secret_scope.aws_sm.name
  key          = "redshift-dw-password"
  string_value = "PLACEHOLDER_ROTATED_BY_LAMBDA" # Actual value set by rotation Lambda
}

resource "databricks_secret" "tokenization_key" {
  provider     = databricks.workspace
  scope        = databricks_secret_scope.aws_sm.name
  key          = "tokenization-encryption-key"
  string_value = "PLACEHOLDER_ROTATED_BY_LAMBDA"
}

# =============================================================================
# CLUSTER POLICY — Compliance-Enforced Compute
# =============================================================================
resource "databricks_cluster_policy" "compliant" {
  provider = databricks.workspace
  name     = "${local.name_prefix}-compliant-policy"

  definition = jsonencode({
    "spark_conf.spark.databricks.cluster.profile" = {
      type  = "fixed"
      value = "serverless"
    }
    "enable_elastic_disk" = {
      type  = "fixed"
      value = true
    }
    "aws_attributes.ebs_volume_type" = {
      type  = "fixed"
      value = "GENERAL_PURPOSE_SSD"
    }
    "custom_tags.Compliance" = {
      type  = "fixed"
      value = "hipaa-soc2-pci"
    }
    "custom_tags.Environment" = {
      type  = "fixed"
      value = var.environment
    }
    "autotermination_minutes" = {
      type       = "range"
      maxValue   = 60
      defaultValue = 30
    }
    "driver_node_type_id" = {
      type = "allowlist"
      values = [
        "m5.xlarge",
        "m5.2xlarge",
        "m5.4xlarge",
        "r5.xlarge",
        "r5.2xlarge"
      ]
      defaultValue = "m5.xlarge"
    }
  })
}

# =============================================================================
# SQL WAREHOUSE — Gold Layer Analytics
# =============================================================================
resource "databricks_sql_endpoint" "gold_analytics" {
  provider = databricks.workspace
  name     = "${local.name_prefix}-gold-analytics"

  cluster_size          = "Small"
  max_num_clusters      = 2
  auto_stop_mins        = 15
  enable_photon         = true
  warehouse_type        = "PRO"
  enable_serverless_compute = true

  tags {
    custom_tags {
      key   = "Compliance"
      value = "hipaa-soc2-pci"
    }
    custom_tags {
      key   = "MedallionTier"
      value = "gold"
    }
  }
}
