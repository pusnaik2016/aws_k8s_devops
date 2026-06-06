# -----------------------------------------------------------------------------
# Root Module — Module Composition
# AWS IoT Greengrass v2 PoC
# Author: Pushparaj Naik
# -----------------------------------------------------------------------------
# This is the orchestration layer that wires all modules together.
# Module dependency order:
#   1. Storage + Monitoring (no dependencies)
#   2. Lambda (depends on monitoring for SNS)
#   3. IAM (depends on storage, lambda, monitoring)
#   4. IoT Core (no module dependencies)
#   5. IoT Greengrass (depends on IAM, IoT Core)
#   6. IoT Rules (depends on storage, lambda, IAM)
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# Module 1: Storage — S3 + Timestream
# No dependencies — created first
# -----------------------------------------------------------------------------
module "storage" {
  source = "./modules/storage"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
  account_id   = data.aws_caller_identity.current.account_id
  kms_key_arn  = module.iam.kms_key_arn

  s3_transition_ia_days              = var.s3_transition_ia_days
  s3_transition_glacier_days         = var.s3_transition_glacier_days
  s3_expiration_days                 = var.s3_expiration_days
  timestream_memory_retention_hours  = var.timestream_memory_retention_hours
  timestream_magnetic_retention_days = var.timestream_magnetic_retention_days
}

# -----------------------------------------------------------------------------
# Module 2: Monitoring — SNS + CloudWatch
# Depends on Lambda (for alarm dimension)
# -----------------------------------------------------------------------------
module "monitoring" {
  source = "./modules/monitoring"

  project_name         = var.project_name
  environment          = var.environment
  aws_region           = var.aws_region
  kms_key_id           = module.iam.kms_key_id
  alert_email          = var.alert_email
  lambda_function_name = module.lambda.alert_function_name
}

# -----------------------------------------------------------------------------
# Module 3: Lambda — Alert Processor
# Depends on monitoring (SNS topic) and IAM (execution role)
# -----------------------------------------------------------------------------
module "lambda" {
  source = "./modules/lambda"

  project_name         = var.project_name
  environment          = var.environment
  lambda_exec_role_arn = module.iam.lambda_exec_role_arn
  sns_topic_arn        = module.monitoring.sns_topic_arn
  kms_key_arn          = module.iam.kms_key_arn
}

# -----------------------------------------------------------------------------
# Module 4: IAM — Roles, Policies, KMS
# Depends on storage (bucket ARN), lambda (ARN), monitoring (SNS ARN)
# -----------------------------------------------------------------------------
module "iam" {
  source = "./modules/iam"

  project_name         = var.project_name
  environment          = var.environment
  telemetry_bucket_arn = module.storage.s3_bucket_arn
  timestream_table_arn = module.storage.timestream_table_arn
  alert_lambda_arn     = module.lambda.alert_function_arn
  sns_topic_arn        = module.monitoring.sns_topic_arn
}

# -----------------------------------------------------------------------------
# Module 5: IoT Core — Things, Certificates, Policies
# No module dependencies
# -----------------------------------------------------------------------------
module "iot_core" {
  source = "./modules/iot_core"

  project_name           = var.project_name
  environment            = var.environment
  aws_region             = var.aws_region
  account_id             = data.aws_caller_identity.current.account_id
  customer_sites         = var.customer_sites
  telemetry_topic_prefix = var.telemetry_topic_prefix
}

# -----------------------------------------------------------------------------
# Module 6: IoT Greengrass — TES, Role Alias, Deployment
# Depends on IAM (TES role) and IoT Core (certificates, thing group)
# -----------------------------------------------------------------------------
module "iot_greengrass" {
  source = "./modules/iot_greengrass"

  project_name            = var.project_name
  environment             = var.environment
  greengrass_tes_role_arn = module.iam.greengrass_tes_role_arn
  certificate_arns        = module.iot_core.certificate_arns
  thing_group_arn         = module.iot_core.thing_group_arn
  kms_key_arn             = module.iam.kms_key_arn
}

# -----------------------------------------------------------------------------
# Module 7: IoT Rules Engine — Telemetry routing & alerting
# Depends on storage, lambda, IAM
# -----------------------------------------------------------------------------
module "iot_rules" {
  source = "./modules/iot_rules"

  project_name                = var.project_name
  environment                 = var.environment
  telemetry_topic_prefix      = var.telemetry_topic_prefix
  iot_rules_role_arn          = module.iam.iot_rules_role_arn
  s3_bucket_name              = module.storage.s3_bucket_name
  timestream_database_name    = module.storage.timestream_database_name
  timestream_table_name       = module.storage.timestream_table_name
  alert_lambda_arn            = module.lambda.alert_function_arn
  alert_temperature_threshold = var.alert_temperature_threshold
  alert_humidity_threshold    = var.alert_humidity_threshold
}
