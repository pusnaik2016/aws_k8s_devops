# ─────────────────────────────────────────────────────────────
# Compute Module — Outputs
# ─────────────────────────────────────────────────────────────

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority" {
  description = "EKS cluster CA certificate"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "cluster_oidc_provider_url" {
  description = "OIDC provider URL"
  value       = local.oidc_provider_url
}

output "chat_service_irsa_role_arn" {
  description = "IRSA role ARN for chat service"
  value       = aws_iam_role.chat_service.arn
}

output "analytics_service_irsa_role_arn" {
  description = "IRSA role ARN for analytics service"
  value       = aws_iam_role.analytics_service.arn
}

output "alb_controller_role_arn" {
  description = "IRSA role ARN for ALB controller"
  value       = aws_iam_role.alb_controller.arn
}
