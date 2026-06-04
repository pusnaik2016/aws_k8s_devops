# =============================================================================
# AWS MODULE OUTPUTS
# =============================================================================

output "vpc_id" {
  description = "AWS VPC ID"
  value       = aws_vpc.main.id
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API server endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_certificate_authority" {
  description = "EKS cluster CA certificate (base64)"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "eks_oidc_provider_arn" {
  description = "EKS OIDC provider ARN for IRSA"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "aurora_cluster_endpoint" {
  description = "Aurora PostgreSQL writer endpoint"
  value       = aws_rds_cluster.aurora.endpoint
}

output "aurora_reader_endpoint" {
  description = "Aurora PostgreSQL reader endpoint"
  value       = aws_rds_cluster.aurora.reader_endpoint
}

output "elasticache_endpoint" {
  description = "ElastiCache Redis configuration endpoint"
  value       = aws_elasticache_replication_group.redis.configuration_endpoint_address
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "vpn_gateway_ip" {
  description = "AWS VPN Gateway public IP"
  value       = aws_vpn_gateway.main.id
}

output "kms_key_arn" {
  description = "Primary KMS key ARN"
  value       = aws_kms_key.main.arn
}

# --- Container Registry ---
output "ecr_repository_urls" {
  description = "ECR repository URLs for all microservices"
  value = {
    for svc, repo in aws_ecr_repository.services : svc => repo.repository_url
  }
}

output "ecr_registry_id" {
  description = "ECR registry ID (AWS account ID)"
  value       = values(aws_ecr_repository.services)[0].registry_id
}

# --- VPC Endpoints ---
output "vpc_endpoint_ecr_api_id" {
  description = "VPC Interface Endpoint ID for ECR API"
  value       = aws_vpc_endpoint.ecr_api.id
}

output "vpc_endpoint_ecr_dkr_id" {
  description = "VPC Interface Endpoint ID for ECR Docker"
  value       = aws_vpc_endpoint.ecr_dkr.id
}
