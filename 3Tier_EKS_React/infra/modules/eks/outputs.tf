output "cluster_name" {
  description = "EKS cluster name"
  value       = module.cluster.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.cluster.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "EKS cluster CA certificate (base64)"
  value       = module.cluster.cluster_certificate_authority_data
  sensitive   = true
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = module.cluster.oidc_provider_arn
}

output "oidc_provider" {
  description = "OIDC provider URL (without https://)"
  value       = module.cluster.oidc_provider
}
