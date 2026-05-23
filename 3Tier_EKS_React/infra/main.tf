# =============================================================================
# Root Module — Module Orchestration
# Project: 3-Tier EKS Application
# Author: Pushparaj Naik
#
# This file is the single entry point for all infrastructure.
# Each concern is delegated to a dedicated module.
# =============================================================================

# --- Data Sources ---
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}
data "aws_partition" "current" {}

# =============================================================================
# 1. Networking
# =============================================================================
module "eks_network" {
  source = "./modules/network"

  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
  availability_zones   = slice(data.aws_availability_zones.available.names, 0, 2)
  cluster_name         = "${var.prefix}-${var.environment}-cluster"
  environment          = var.environment
  prefix               = var.prefix
  enable_flow_logs     = true
}

# =============================================================================
# 2. EKS Cluster
# =============================================================================
module "eks" {
  source = "./modules/eks"

  prefix              = var.prefix
  environment         = var.environment
  vpc_id              = module.eks_network.vpc_id
  subnet_ids          = module.eks_network.private_subnets
  node_instance_types = var.eks_node_instance_types
  node_min_size       = var.eks_node_min_size
  node_max_size       = var.eks_node_max_size
  node_desired_size   = var.eks_node_desired_size
}

# =============================================================================
# 3. RDS PostgreSQL
# =============================================================================
module "rds" {
  source = "./modules/rds"

  prefix             = var.prefix
  environment        = var.environment
  vpc_id             = module.eks_network.vpc_id
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
  db_settings        = var.db_default_settings
  enable_dr          = var.enable_dr
}

# =============================================================================
# 4. GitHub OIDC
# =============================================================================
module "github_oidc" {
  source = "./modules/oidc"

  prefix              = var.prefix
  environment         = var.environment
  github_repositories = var.github_repositories
  eks_cluster_name    = module.eks.cluster_name
  account_id          = data.aws_caller_identity.current.account_id
}

# =============================================================================
# 5. ArgoCD (GitOps)
# =============================================================================
module "argocd" {
  source = "./modules/argocd"

  enable                 = var.enable_argocd
  chart_version          = var.argocd_chart_version
  namespace              = var.argocd_namespace
  environment            = var.environment
  gitops_repo_url        = var.gitops_repo_url
  gitops_target_revision = var.gitops_target_revision

  depends_on = [module.eks]
}

# =============================================================================
# 6. External Secrets Operator
# =============================================================================
module "external_secrets" {
  source = "./modules/external-secrets"

  enable            = var.enable_external_secrets
  chart_version     = var.external_secrets_chart_version
  prefix            = var.prefix
  environment       = var.environment
  aws_region        = var.aws_region
  account_id        = data.aws_caller_identity.current.account_id
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider     = module.eks.oidc_provider
  db_secret_arn     = module.rds.secret_arn
  kms_key_arn       = module.rds.kms_key_arn

  depends_on = [module.eks]
}

# =============================================================================
# 7. Compliance & DR
# =============================================================================
module "compliance" {
  source = "./modules/compliance"

  providers = {
    aws           = aws
    aws.dr_region = aws.dr_region
  }

  prefix                 = var.prefix
  environment            = var.environment
  account_id             = data.aws_caller_identity.current.account_id
  enable_guardduty       = var.enable_guardduty
  enable_dr              = var.enable_dr
  db_instance_identifier = module.rds.instance_identifier
}

# =============================================================================
# 8. Remote State Management
# =============================================================================
module "state" {
  source = "./modules/state"

  prefix      = var.prefix
  environment = var.environment
  kms_key_arn = module.rds.kms_key_arn
}
