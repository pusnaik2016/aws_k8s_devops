# ─────────────────────────────────────────────────────────────
# Root Module — Staging (reduced resources)
# ─────────────────────────────────────────────────────────────
locals {
  common_tags = { Project = var.project_name; Environment = var.environment; ManagedBy = "terraform" }
}

module "networking" {
  source             = "../../modules/networking"
  project_name       = var.project_name
  environment        = var.environment
  aws_region         = var.aws_region
  single_nat_gateway = true
  tags               = local.common_tags
}

module "security" {
  source          = "../../modules/security"
  project_name    = var.project_name
  environment     = var.environment
  vpc_id          = module.networking.vpc_id
  vpc_cidr_block  = module.networking.vpc_cidr_block
  github_org_repo = var.github_org_repo
  tags            = local.common_tags
}

module "compute" {
  source                      = "../../modules/compute"
  project_name                = var.project_name
  environment                 = var.environment
  aws_region                  = var.aws_region
  vpc_id                      = module.networking.vpc_id
  private_subnet_ids          = module.networking.private_subnet_ids
  eks_cluster_role_arn        = module.security.eks_cluster_role_arn
  eks_node_group_role_arn     = module.security.eks_node_group_role_arn
  eks_nodes_security_group_id = module.security.eks_nodes_security_group_id
  kms_eks_key_arn             = module.security.kms_eks_key_arn
  node_instance_types         = ["t3.medium"]
  node_min_size               = 1
  node_max_size               = 3
  node_desired_size           = 1
  tags                        = local.common_tags
}

module "database" {
  source                     = "../../modules/database"
  project_name               = var.project_name
  environment                = var.environment
  vpc_id                     = module.networking.vpc_id
  private_subnet_ids         = module.networking.private_subnet_ids
  aurora_security_group_id   = module.security.aurora_security_group_id
  redis_security_group_id    = module.security.redis_security_group_id
  kms_aurora_key_arn         = module.security.kms_aurora_key_arn
  aurora_min_capacity        = 0.5
  aurora_max_capacity        = 2
  aurora_master_password_ssm = module.security.aurora_password_ssm_arn
  redis_node_type            = "cache.t3.medium"
  redis_auth_token_ssm       = module.security.redis_auth_token_ssm_arn
  tags                       = local.common_tags
}

module "ai_cdn" {
  source          = "../../modules/ai_cdn"
  project_name    = var.project_name
  environment     = var.environment
  aws_region      = var.aws_region
  route53_zone_id = module.networking.route53_zone_id
  kms_s3_key_arn  = module.security.kms_s3_key_arn
  tags            = local.common_tags
}
