output "api_gateway_url" {
  description = "API Gateway invoke URL"
  value       = module.api_gateway.invoke_url
}

output "s3_bucket_name" {
  description = "S3 bucket for document uploads"
  value       = module.s3.bucket_name
}

output "opensearch_endpoint" {
  description = "OpenSearch Serverless collection endpoint"
  value       = module.opensearch.collection_endpoint
}

output "chat_lambda_arn" {
  description = "Chat Lambda function ARN"
  value       = module.lambda.chat_function_arn
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}
