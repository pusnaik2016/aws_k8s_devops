output "agent_id" {
  description = "ID of the Bedrock Agent"
  value       = module.agent.agent_id
}

output "agent_alias_id" {
  description = "ID of the live agent alias"
  value       = module.agent.agent_alias_id
}

output "knowledge_base_id" {
  description = "ID of the Bedrock Knowledge Base"
  value       = module.knowledge_base.knowledge_base_id
}

output "memory_bucket_name" {
  description = "S3 bucket for memory documents"
  value       = module.knowledge_base.memory_bucket_name
}

output "aurora_cluster_endpoint" {
  description = "Aurora cluster writer endpoint"
  value       = module.aurora.cluster_endpoint
}

output "lambda_function_name" {
  description = "Memory writer Lambda function name"
  value       = module.session_memory.lambda_function_name
}

output "dynamodb_table_name" {
  description = "DynamoDB sessions table name"
  value       = module.session_memory.dynamodb_table_name
}

output "cloudwatch_dashboard" {
  description = "CloudWatch dashboard name"
  value       = module.observability.dashboard_name
}
