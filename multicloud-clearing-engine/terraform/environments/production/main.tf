# =============================================================================
# ROOT MODULE — Production Environment
# Global Healthcare & Financial Transaction Clearing Engine
# =============================================================================
# This root module orchestrates all three cloud provider modules and wires
# cross-cloud dependencies (VPN peer IPs, shared secrets, compliance outputs).
# =============================================================================

# -----------------------------------------------------------------------------
# AWS Infrastructure — Primary Active Site
# -----------------------------------------------------------------------------
module "aws_infra" {
  source = "../../modules/aws_infra"

  project_name = var.project_name
  environment  = var.environment
  domain_name  = var.domain_name

  # Networking
  vpc_cidr = var.aws_vpc_cidr
  region   = var.aws_region

  # EKS
  eks_cluster_version    = var.aws_eks_cluster_version
  eks_node_instance_type = var.aws_eks_node_instance_type
  eks_node_min           = var.aws_eks_node_min
  eks_node_max           = var.aws_eks_node_max

  # Aurora
  aurora_instance_class        = var.aws_aurora_instance_class
  aurora_reader_instance_class  = var.aws_aurora_reader_instance_class

  # ElastiCache
  elasticache_node_type = var.aws_elasticache_node_type

  # Compliance
  enable_hipaa   = var.enable_hipaa
  enable_sox     = var.enable_sox
  enable_gdpr    = var.enable_gdpr
  enable_pci_dss = var.enable_pci_dss

  # Cross-Cloud VPN Peers (resolved after Azure/GCP modules create their gateways)
  azure_vpn_gateway_ip = module.azure_infra.vpn_gateway_ip
  gcp_vpn_gateway_ip   = module.gcp_infra.vpn_gateway_ip
  azure_vnet_cidr      = var.azure_vnet_cidr
  gcp_vpc_cidr         = var.gcp_vpc_cidr

  vpn_shared_secret_azure = var.vpn_shared_secret_aws_azure
  vpn_shared_secret_gcp   = var.vpn_shared_secret_aws_gcp

  common_tags = var.common_tags
}

# -----------------------------------------------------------------------------
# Azure Infrastructure — Hot Standby Site
# -----------------------------------------------------------------------------
module "azure_infra" {
  source = "../../modules/azure_infra"

  project_name = var.project_name
  environment  = var.environment
  domain_name  = var.domain_name

  # Networking
  vnet_address_space = var.azure_vnet_cidr
  location           = var.azure_region

  # AKS
  aks_node_vm_size    = var.azure_aks_node_vm_size
  aks_system_node_min = var.azure_aks_system_node_min
  aks_system_node_max = var.azure_aks_system_node_max
  aks_user_node_min   = var.azure_aks_user_node_min
  aks_user_node_max   = var.azure_aks_user_node_max

  # Azure SQL
  sql_sku = var.azure_sql_sku

  # Compliance
  enable_hipaa   = var.enable_hipaa
  enable_sox     = var.enable_sox
  enable_gdpr    = var.enable_gdpr
  enable_pci_dss = var.enable_pci_dss

  # Azure AD User Management
  azure_ad_admin_group_name      = var.azure_ad_admin_group_name
  azure_ad_dev_group_name        = var.azure_ad_dev_group_name
  azure_ad_compliance_group_name = var.azure_ad_compliance_group_name
  azure_ad_admin_users           = var.azure_ad_admin_users
  azure_tenant_id                = var.azure_tenant_id

  # Cross-Cloud VPN Peers
  aws_vpn_gateway_ip = module.aws_infra.vpn_gateway_ip
  gcp_vpn_gateway_ip = module.gcp_infra.vpn_gateway_ip
  aws_vpc_cidr       = var.aws_vpc_cidr
  gcp_vpc_cidr       = var.gcp_vpc_cidr

  vpn_shared_secret_aws = var.vpn_shared_secret_aws_azure
  vpn_shared_secret_gcp = var.vpn_shared_secret_azure_gcp

  common_tags = var.common_tags
}

# -----------------------------------------------------------------------------
# GCP Infrastructure — Compliance & Analytics Layer
# -----------------------------------------------------------------------------
module "gcp_infra" {
  source = "../../modules/gcp_infra"

  project_name = var.project_name
  environment  = var.environment

  # Networking
  vpc_cidr   = var.gcp_vpc_cidr
  region     = var.gcp_region
  project_id = var.gcp_project_id

  # GKE
  gke_node_machine_type = var.gcp_gke_node_machine_type
  gke_node_min          = var.gcp_gke_node_min
  gke_node_max          = var.gcp_gke_node_max

  # AlloyDB
  alloydb_cpu_count = var.gcp_alloydb_cpu_count

  # Compliance
  enable_hipaa   = var.enable_hipaa
  enable_sox     = var.enable_sox
  enable_gdpr    = var.enable_gdpr
  enable_pci_dss = var.enable_pci_dss

  # Cross-Cloud VPN Peers
  aws_vpn_gateway_ip   = module.aws_infra.vpn_gateway_ip
  azure_vpn_gateway_ip = module.azure_infra.vpn_gateway_ip
  aws_vpc_cidr         = var.aws_vpc_cidr
  azure_vnet_cidr      = var.azure_vnet_cidr

  vpn_shared_secret_aws   = var.vpn_shared_secret_aws_gcp
  vpn_shared_secret_azure = var.vpn_shared_secret_azure_gcp

  common_labels = var.common_tags
}
