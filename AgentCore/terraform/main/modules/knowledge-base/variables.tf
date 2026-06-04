variable "name" {
  description = "Name prefix for Knowledge Base resources"
  type        = string
  default     = "agentcore-memory"
}

variable "aurora_cluster_arn" {
  description = "ARN of the Aurora pgvector cluster"
  type        = string
}

variable "aurora_secret_arn" {
  description = "ARN of the Aurora master user secret"
  type        = string
}

variable "aurora_database_name" {
  description = "Database name in Aurora"
  type        = string
  default     = "agentcore"
}

variable "embedding_model" {
  description = "Bedrock embedding model ID"
  type        = string
  default     = "amazon.titan-embed-text-v2:0"
}
