variable "name" {
  description = "Name prefix for session memory resources"
  type        = string
  default     = "agentcore-memory"
}

variable "memory_bucket_name" {
  description = "Name of the S3 bucket for memory documents"
  type        = string
}

variable "memory_bucket_arn" {
  description = "ARN of the S3 bucket for memory documents"
  type        = string
}

variable "knowledge_base_id" {
  description = "ID of the Bedrock Knowledge Base"
  type        = string
}

variable "knowledge_base_arn" {
  description = "ARN of the Bedrock Knowledge Base"
  type        = string
}

variable "data_source_id" {
  description = "ID of the KB data source"
  type        = string
}

variable "lambda_source_dir" {
  description = "Path to the Lambda source code directory"
  type        = string
}

variable "confidence_threshold" {
  description = "Minimum confidence for persisting a fact (0.0-1.0)"
  type        = number
  default     = 0.7
}
