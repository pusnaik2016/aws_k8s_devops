# ─────────────────────────────────────────────────────────────────────────────
# Dev Environment — EKS Retail Platform
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(var.common_tags, {
      Environment = "dev"
    })
  }
}

locals {
  environment  = "dev"
  name_prefix  = "${var.project_name}-${local.environment}"
  cluster_name = "${local.name_prefix}-eks"
}

# ─── VPC ─────────────────────────────────────────────────────────────────────

module "vpc" {
  source = "../../modules/vpc"

  name_prefix        = local.name_prefix
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  aws_region         = var.aws_region
  cluster_name       = local.cluster_name
  single_nat_gateway = true # Cost savings for dev
  log_retention_days = 90   # Shorter retention for dev
  common_tags        = var.common_tags
}

# ─── Security ────────────────────────────────────────────────────────────────

module "security" {
  source = "../../modules/security"

  name_prefix         = local.name_prefix
  environment         = local.environment
  aws_region          = var.aws_region
  enable_waf          = false # Disabled in dev
  enable_guardduty    = true
  enable_security_hub = false # Disabled in dev
  log_retention_days  = 90
  common_tags         = var.common_tags
}

# ─── EKS ─────────────────────────────────────────────────────────────────────

module "eks" {
  source = "../../modules/eks"

  name_prefix               = local.name_prefix
  cluster_name              = local.cluster_name
  kubernetes_version        = var.kubernetes_version
  environment               = local.environment
  vpc_id                    = module.vpc.vpc_id
  vpc_cidr                  = module.vpc.vpc_cidr
  private_subnet_ids        = module.vpc.private_subnet_ids
  system_node_instance_type = "m6i.large"
  system_node_count = {
    min     = 2
    max     = 3
    desired = 2
  }
  log_retention_days = 90
  common_tags        = var.common_tags
}

# ─── Karpenter ───────────────────────────────────────────────────────────────

module "karpenter" {
  source = "../../modules/karpenter"

  name_prefix       = local.name_prefix
  cluster_name      = local.cluster_name
  aws_region        = var.aws_region
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  common_tags       = var.common_tags
}

# ─── Database ────────────────────────────────────────────────────────────────

module "database" {
  source = "../../modules/database"

  name_prefix          = local.name_prefix
  environment          = local.environment
  vpc_id               = module.vpc.vpc_id
  vpc_cidr             = module.vpc.vpc_cidr
  db_subnet_group_name = module.vpc.db_subnet_group_name
  kms_key_arn          = module.security.kms_key_arn
  db_scaling = {
    min_acu = 0.5
    max_acu = 4
  }
  backup_retention_days = 7
  common_tags           = var.common_tags
}

# ─── Messaging ───────────────────────────────────────────────────────────────

module "messaging" {
  source = "../../modules/messaging"

  name_prefix       = local.name_prefix
  kms_key_arn       = module.security.kms_key_arn
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  common_tags       = var.common_tags
}

# ─── Observability ───────────────────────────────────────────────────────────

module "observability" {
  source = "../../modules/observability"

  name_prefix        = local.name_prefix
  cluster_name       = local.cluster_name
  aws_region         = var.aws_region
  kms_key_arn        = module.security.kms_key_arn
  log_retention_days = 90
  oidc_provider_arn  = module.eks.oidc_provider_arn
  oidc_provider_url  = module.eks.oidc_provider_url
  common_tags        = var.common_tags
}

# ─── Outputs ─────────────────────────────────────────────────────────────────

output "cluster_name" { value = module.eks.cluster_name }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "ecr_urls" { value = module.security.ecr_repository_urls }
output "order_queue_url" { value = module.messaging.order_queue_url }
output "notification_queue_url" { value = module.messaging.notification_queue_url }
output "db_endpoint" { value = module.database.cluster_endpoint }
