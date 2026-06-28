# =============================================================================
# PRODUCTION ENVIRONMENT — AWS Primary Active Site
# =============================================================================
# Root composition: Wires all AWS modules + cross-cloud transit
# =============================================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = { source = "hashicorp/aws"; version = "~> 5.0" }
    azurerm = { source = "hashicorp/azurerm"; version = "~> 3.80" }
    databricks = { source = "databricks/databricks"; version = "~> 1.30" }
  }

  backend "s3" {
    bucket         = "medallion-platform-tfstate"
    key            = "production/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region
  default_tags { tags = var.common_tags }
}

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

provider "databricks" {
  alias      = "mws"
  host       = "https://accounts.cloud.databricks.com"
  account_id = var.databricks_account_id
}

provider "databricks" {
  alias = "workspace"
  host  = module.aws_databricks.workspace_url
}

# =============================================================================
# MODULE COMPOSITION
# =============================================================================

# --- Security (KMS, Secrets, IAM) — must be first (other modules depend on keys) ---
module "aws_security" {
  source = "../../modules/aws-security"

  project_name          = var.project_name
  environment           = var.environment
  common_tags           = var.common_tags
  databricks_account_id = var.databricks_account_id
  audit_log_bucket_name = module.aws_storage.audit_log_bucket_name
  github_org            = var.github_org
  github_repo           = var.github_repo
}

# --- Networking (VPC, Subnets, VPC Endpoints, Direct Connect) ---
module "aws_networking" {
  source = "../../modules/aws-networking"

  project_name     = var.project_name
  environment      = var.environment
  common_tags      = var.common_tags
  vpc_cidr         = var.aws_vpc_cidr
  logs_kms_key_arn = module.aws_security.logs_kms_key_arn
}

# --- Storage (S3 Medallion Buckets + Audit Log Bucket) ---
module "aws_storage" {
  source = "../../modules/aws-storage"

  project_name       = var.project_name
  environment        = var.environment
  common_tags        = var.common_tags
  s3_kms_key_id      = module.aws_security.s3_data_kms_key_id
  logs_kms_key_id    = module.aws_security.logs_kms_key_arn
  s3_vpc_endpoint_id = module.aws_networking.s3_vpc_endpoint_id
}

# --- Databricks (Workspace, Unity Catalog, Secret Scopes) ---
module "aws_databricks" {
  source = "../../modules/aws-databricks"

  providers = {
    databricks.mws       = databricks.mws
    databricks.workspace = databricks.workspace
  }

  project_name                     = var.project_name
  environment                      = var.environment
  common_tags                      = var.common_tags
  aws_region                       = var.aws_region
  databricks_account_id            = var.databricks_account_id
  databricks_cross_account_role_arn = module.aws_security.databricks_cross_account_role_arn
  vpc_id                           = module.aws_networking.vpc_id
  private_compute_subnet_ids       = module.aws_networking.private_compute_subnet_ids
  databricks_compute_sg_id         = module.aws_networking.databricks_compute_sg_id
  databricks_scc_relay_vpce_id     = module.aws_networking.s3_vpc_endpoint_id # Placeholder
  databricks_workspace_vpce_id     = module.aws_networking.s3_vpc_endpoint_id # Placeholder
  databricks_kms_key_arn           = module.aws_security.databricks_kms_key_arn
  databricks_kms_key_id            = module.aws_security.s3_data_kms_key_id
  s3_kms_key_arn                   = module.aws_security.s3_data_kms_key_arn
  bronze_bucket_name               = module.aws_storage.bronze_bucket_name
  silver_bucket_name               = module.aws_storage.silver_bucket_name
  gold_bucket_name                 = module.aws_storage.gold_bucket_name
}

# --- Monitoring (CloudWatch, Config, Compliance Dashboards) ---
module "aws_monitoring" {
  source = "../../modules/aws-monitoring"

  project_name              = var.project_name
  environment               = var.environment
  common_tags               = var.common_tags
  aws_region                = var.aws_region
  logs_kms_key_id           = module.aws_security.logs_kms_key_arn
  cloudtrail_log_group_name = "/aws/cloudtrail/${var.project_name}-${var.environment}"
  alert_email_addresses     = var.alert_email_addresses
}

# --- Secrets Rotation (Lambda 90-day policy) ---
module "secrets_rotation" {
  source = "../../modules/secrets-rotation"

  project_name   = var.project_name
  environment    = var.environment
  common_tags    = var.common_tags
  azure_location = var.azure_location

  secret_arns = [
    module.aws_security.databricks_token_secret_arn,
    module.aws_security.warehouse_credentials_secret_arn,
    module.aws_security.tokenization_key_secret_arn,
  ]

  kms_key_arn    = module.aws_security.s3_data_kms_key_arn
  sns_topic_arn  = module.aws_monitoring.compliance_sns_topic_arn
  key_vault_id   = "" # Not used in production (AWS-only rotation)
  key_vault_name = ""
}
