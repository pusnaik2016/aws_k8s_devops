output "knowledge_base_id" {
  description = "ID of the Bedrock Knowledge Base"
  value       = aws_bedrockagent_knowledge_base.this.id
}

output "knowledge_base_arn" {
  description = "ARN of the Bedrock Knowledge Base"
  value       = aws_bedrockagent_knowledge_base.this.arn
}

output "data_source_id" {
  description = "ID of the S3 data source"
  value       = aws_bedrockagent_data_source.this.data_source_id
}

output "memory_bucket_name" {
  description = "Name of the S3 bucket for memory documents"
  value       = aws_s3_bucket.memory_docs.id
}

output "memory_bucket_arn" {
  description = "ARN of the S3 bucket for memory documents"
  value       = aws_s3_bucket.memory_docs.arn
}
