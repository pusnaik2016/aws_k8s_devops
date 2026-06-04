# ─────────────────────────────────────────────────────────────
# Stack Outputs — Staging
# ─────────────────────────────────────────────────────────────

output "vpc_id" {
  value = module.networking.vpc_id
}
output "eks_cluster_name" {
  value = module.compute.cluster_name
}
output "eks_cluster_endpoint" {
  value     = module.compute.cluster_endpoint
  sensitive = true
}
output "aurora_endpoint" {
  value     = module.database.aurora_cluster_endpoint
  sensitive = true
}
output "redis_endpoint" {
  value     = module.database.redis_primary_endpoint
  sensitive = true
}
output "cloudfront_domain" {
  value = module.ai_cdn.cloudfront_domain_name
}
output "websocket_api_url" {
  value = module.ai_cdn.websocket_api_endpoint
}
output "rest_api_url" {
  value = module.ai_cdn.rest_api_endpoint
}
output "github_actions_role_arn" {
  value = module.security.github_actions_role_arn
}
output "chat_service_irsa_role_arn" {
  value = module.compute.chat_service_irsa_role_arn
}
output "analytics_service_irsa_role_arn" {
  value = module.compute.analytics_service_irsa_role_arn
}
