# ─────────────────────────────────────────────────────────────────────────────
# Prod Environment — EKS Retail Platform (Full Compliance)
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = merge(var.common_tags, { Environment = "prod" })
  }
}

locals {
  environment  = "prod"
  name_prefix  = "${var.project_name}-${local.environment}"
  cluster_name = "${local.name_prefix}-eks"
}

module "vpc" {
  source             = "../../modules/vpc"
  name_prefix        = local.name_prefix
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  aws_region         = var.aws_region
  cluster_name       = local.cluster_name
  single_nat_gateway = false # HA: one NAT per AZ
  log_retention_days = 365   # SOC2/HIPAA
  common_tags        = var.common_tags
}

module "security" {
  source              = "../../modules/security"
  name_prefix         = local.name_prefix
  environment         = local.environment
  aws_region          = var.aws_region
  enable_waf          = true
  enable_guardduty    = true
  enable_security_hub = true
  log_retention_days  = 365
  common_tags         = var.common_tags
}

module "eks" {
  source                    = "../../modules/eks"
  name_prefix               = local.name_prefix
  cluster_name              = local.cluster_name
  kubernetes_version        = var.kubernetes_version
  environment               = local.environment
  vpc_id                    = module.vpc.vpc_id
  vpc_cidr                  = module.vpc.vpc_cidr
  private_subnet_ids        = module.vpc.private_subnet_ids
  system_node_instance_type = "m6i.xlarge"
  system_node_count         = { min = 2, max = 6, desired = 3 }
  log_retention_days        = 365
  common_tags               = var.common_tags
}

module "karpenter" {
  source            = "../../modules/karpenter"
  name_prefix       = local.name_prefix
  cluster_name      = local.cluster_name
  aws_region        = var.aws_region
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  common_tags       = var.common_tags
}

module "database" {
  source               = "../../modules/database"
  name_prefix          = local.name_prefix
  environment          = local.environment
  vpc_id               = module.vpc.vpc_id
  vpc_cidr             = module.vpc.vpc_cidr
  db_subnet_group_name = module.vpc.db_subnet_group_name
  kms_key_arn          = module.security.kms_key_arn
  db_scaling           = { min_acu = 4, max_acu = 64 }
  backup_retention_days = 35 # HIPAA
  common_tags          = var.common_tags
}

module "messaging" {
  source            = "../../modules/messaging"
  name_prefix       = local.name_prefix
  kms_key_arn       = module.security.kms_key_arn
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  common_tags       = var.common_tags
}

module "observability" {
  source             = "../../modules/observability"
  name_prefix        = local.name_prefix
  cluster_name       = local.cluster_name
  aws_region         = var.aws_region
  kms_key_arn        = module.security.kms_key_arn
  log_retention_days = 365
  oidc_provider_arn  = module.eks.oidc_provider_arn
  oidc_provider_url  = module.eks.oidc_provider_url
  common_tags        = var.common_tags
}

output "cluster_name" { value = module.eks.cluster_name }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
