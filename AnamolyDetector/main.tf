###############################################################################
# AWS Cost Anomaly Detector — Root Configuration
# Deploys a $2/month intelligent cost monitoring system using Z-score
# statistics and Claude 3.5 Sonnet via Amazon Bedrock.
###############################################################################

terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "cost-anomaly-detector"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

###############################################################################
# Storage — DynamoDB with TTL for cost history
###############################################################################
module "storage" {
  source         = "./modules/storage"
  table_name     = "cost-history"
  retention_days = 90
  environment    = var.environment
}

###############################################################################
# Bedrock — Claude model configuration
###############################################################################
module "bedrock_config" {
  source     = "./modules/bedrock_config"
  model_id   = var.bedrock_model_id
  aws_region = var.aws_region
}

###############################################################################
# Notifications — SNS topic + email subscription
###############################################################################
module "notifications" {
  source      = "./modules/notifications"
  topic_name  = "cost-anomaly-alerts"
  alert_email = var.alert_email
  environment = var.environment
}

###############################################################################
# Cost Analyzer — Fetcher + Detector Lambdas, EventBridge Schedulers, IAM
###############################################################################
module "cost_analyzer" {
  source = "./modules/cost_analyzer"

  environment        = var.environment
  aws_region         = var.aws_region
  dynamodb_table     = module.storage.table_name
  dynamodb_arn       = module.storage.table_arn
  sns_topic_arn      = module.notifications.topic_arn
  bedrock_model_id   = module.bedrock_config.model_id
  zscore_threshold   = var.zscore_threshold
  retention_days     = module.storage.retention_days
  fetcher_schedule   = var.fetcher_schedule
  detector_schedule  = var.detector_schedule
  log_retention_days = var.log_retention_days
  log_level          = var.log_level
}
