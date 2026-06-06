# =============================================================================
# ROOT OUTPUTS — Production Environment
# =============================================================================

# -----------------------------------------------------------------------------
# AWS Outputs
# -----------------------------------------------------------------------------
output "aws_vpc_id" {
  description = "AWS VPC ID"
  value       = module.aws_infra.vpc_id
}

output "aws_eks_cluster_endpoint" {
  description = "AWS EKS cluster API endpoint"
  value       = module.aws_infra.eks_cluster_endpoint
  sensitive   = true
}

output "aws_eks_cluster_name" {
  description = "AWS EKS cluster name"
  value       = module.aws_infra.eks_cluster_name
}

output "aws_aurora_cluster_endpoint" {
  description = "Aurora PostgreSQL writer endpoint"
  value       = module.aws_infra.aurora_cluster_endpoint
  sensitive   = true
}

output "aws_aurora_reader_endpoint" {
  description = "Aurora PostgreSQL reader endpoint"
  value       = module.aws_infra.aurora_reader_endpoint
  sensitive   = true
}

output "aws_elasticache_endpoint" {
  description = "ElastiCache Redis configuration endpoint"
  value       = module.aws_infra.elasticache_endpoint
  sensitive   = true
}

output "aws_cloudfront_domain" {
  description = "CloudFront distribution domain name"
  value       = module.aws_infra.cloudfront_domain_name
}

output "aws_vpn_gateway_ip" {
  description = "AWS VPN Gateway public IP"
  value       = module.aws_infra.vpn_gateway_ip
}

# -----------------------------------------------------------------------------
# Azure Outputs
# -----------------------------------------------------------------------------
output "azure_resource_group" {
  description = "Azure resource group name"
  value       = module.azure_infra.resource_group_name
}

output "azure_aks_cluster_endpoint" {
  description = "AKS cluster API endpoint"
  value       = module.azure_infra.aks_cluster_endpoint
  sensitive   = true
}

output "azure_aks_cluster_name" {
  description = "AKS cluster name"
  value       = module.azure_infra.aks_cluster_name
}

output "azure_sql_fqdn" {
  description = "Azure SQL Hyperscale fully qualified domain name"
  value       = module.azure_infra.sql_server_fqdn
  sensitive   = true
}

output "azure_frontdoor_endpoint" {
  description = "Azure Front Door endpoint hostname"
  value       = module.azure_infra.frontdoor_endpoint
}

output "azure_vpn_gateway_ip" {
  description = "Azure VPN Gateway public IP"
  value       = module.azure_infra.vpn_gateway_ip
}

# -----------------------------------------------------------------------------
# GCP Outputs
# -----------------------------------------------------------------------------
output "gcp_vpc_name" {
  description = "GCP VPC network name"
  value       = module.gcp_infra.vpc_name
}

output "gcp_gke_cluster_endpoint" {
  description = "GKE cluster API endpoint"
  value       = module.gcp_infra.gke_cluster_endpoint
  sensitive   = true
}

output "gcp_gke_cluster_name" {
  description = "GKE cluster name"
  value       = module.gcp_infra.gke_cluster_name
}

output "gcp_alloydb_ip" {
  description = "AlloyDB primary instance IP address"
  value       = module.gcp_infra.alloydb_primary_ip
  sensitive   = true
}

output "gcp_bigquery_dataset_id" {
  description = "BigQuery compliance audit dataset ID"
  value       = module.gcp_infra.bigquery_audit_dataset_id
}

output "gcp_vpn_gateway_ip" {
  description = "GCP HA VPN Gateway IP"
  value       = module.gcp_infra.vpn_gateway_ip
}

# -----------------------------------------------------------------------------
# Cross-Cloud Summary
# -----------------------------------------------------------------------------
output "multicloud_vpn_mesh_status" {
  description = "Summary of cross-cloud VPN mesh connectivity"
  value = {
    aws_to_azure = "AWS (${module.aws_infra.vpn_gateway_ip}) ↔ Azure (${module.azure_infra.vpn_gateway_ip})"
    aws_to_gcp   = "AWS (${module.aws_infra.vpn_gateway_ip}) ↔ GCP (${module.gcp_infra.vpn_gateway_ip})"
    azure_to_gcp = "Azure (${module.azure_infra.vpn_gateway_ip}) ↔ GCP (${module.gcp_infra.vpn_gateway_ip})"
  }
}
