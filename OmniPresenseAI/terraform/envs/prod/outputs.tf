# ─────────────────────────────────────────────────────────────
# Stack Outputs — Production
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

# ─── Compliance Outputs ──────────────────────────────────────
output "cloudtrail_arn" {
  value = module.compliance.cloudtrail_arn
}
output "guardduty_detector_id" {
  value = module.compliance.guardduty_detector_id
}
output "security_hub_arn" {
  value = module.compliance.security_hub_arn
}
output "waf_web_acl_arn" {
  value = module.compliance.waf_web_acl_arn
}

# ─── AI Governance Outputs ───────────────────────────────────
output "bedrock_guardrail_id" {
  value = module.ai_governance.guardrail_id
}
output "bedrock_guardrail_version" {
  value = module.ai_governance.guardrail_version
}
