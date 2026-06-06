# ─────────────────────────────────────────────────────────────
# Root Module — Production Environment
# ─────────────────────────────────────────────────────────────
# Composes all infrastructure modules for the production env.
# ─────────────────────────────────────────────────────────────

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ─────────────── Networking ───────────────

module "networking" {
  source = "../../modules/networking"

  project_name       = var.project_name
  environment        = var.environment
  aws_region         = var.aws_region
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  domain_name        = var.domain_name
  single_nat_gateway = true
  tags               = local.common_tags
}

# ─────────────── Security ───────────────

module "security" {
  source = "../../modules/security"

  project_name    = var.project_name
  environment     = var.environment
  vpc_id          = module.networking.vpc_id
  vpc_cidr_block  = module.networking.vpc_cidr_block
  github_org_repo = var.github_org_repo
  tags            = local.common_tags
}

# ─────────────── Compute (EKS) ───────────────

module "compute" {
  source = "../../modules/compute"

  project_name               = var.project_name
  environment                = var.environment
  aws_region                 = var.aws_region
  vpc_id                     = module.networking.vpc_id
  private_subnet_ids         = module.networking.private_subnet_ids
  eks_cluster_role_arn       = module.security.eks_cluster_role_arn
  eks_node_group_role_arn    = module.security.eks_node_group_role_arn
  eks_nodes_security_group_id = module.security.eks_nodes_security_group_id
  kms_eks_key_arn            = module.security.kms_eks_key_arn
  kubernetes_version         = "1.29"
  node_instance_types        = ["m6g.large"]
  node_min_size              = 2
  node_max_size              = 10
  node_desired_size          = 2
  tags                       = local.common_tags
}

# ─────────────── Database ───────────────

module "database" {
  source = "../../modules/database"

  project_name             = var.project_name
  environment              = var.environment
  vpc_id                   = module.networking.vpc_id
  private_subnet_ids       = module.networking.private_subnet_ids
  aurora_security_group_id = module.security.aurora_security_group_id
  redis_security_group_id  = module.security.redis_security_group_id
  kms_aurora_key_arn       = module.security.kms_aurora_key_arn
  aurora_min_capacity      = 0.5
  aurora_max_capacity      = 4
  aurora_master_password_ssm = module.security.aurora_password_ssm_arn
  redis_auth_token_ssm       = module.security.redis_auth_token_ssm_arn
  tags                     = local.common_tags
}

# ─────────────── AI / CDN ───────────────

module "ai_cdn" {
  source = "../../modules/ai_cdn"

  project_name    = var.project_name
  environment     = var.environment
  aws_region      = var.aws_region
  domain_name     = var.domain_name
  route53_zone_id = module.networking.route53_zone_id
  kms_s3_key_arn  = module.security.kms_s3_key_arn
  tags            = local.common_tags
}

# ─────────────── Compliance ───────────────

module "compliance" {
  source = "../../modules/compliance"

  project_name               = var.project_name
  environment                = var.environment
  aws_region                 = var.aws_region
  kms_s3_key_arn             = module.security.kms_s3_key_arn
  alert_email                = var.alert_email
  monthly_budget_limit       = var.monthly_budget_limit
  transcripts_bucket_name    = module.ai_cdn.transcripts_bucket_name
  cloudfront_distribution_arn = module.ai_cdn.cloudfront_distribution_arn
  tags                       = local.common_tags
}

# ─────────────── AI Governance ───────────────

module "ai_governance" {
  source = "../../modules/ai_governance"

  project_name        = var.project_name
  environment         = var.environment
  aws_region          = var.aws_region
  kms_s3_key_arn      = module.security.kms_s3_key_arn
  alert_sns_topic_arn = module.compliance.alerts_sns_topic_arn
  tags                = local.common_tags
}
