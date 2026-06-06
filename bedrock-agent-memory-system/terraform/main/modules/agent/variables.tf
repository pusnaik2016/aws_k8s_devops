variable "name" {
  description = "Name for the Bedrock Agent"
  type        = string
  default     = "agentcore-memory"
}

variable "foundation_model" {
  description = "Bedrock foundation model ID (do NOT use eu. prefix)"
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20241022-v2:0"
}

variable "knowledge_base_id" {
  description = "ID of the Bedrock Knowledge Base to associate"
  type        = string
}

variable "knowledge_base_arn" {
  description = "ARN of the Bedrock Knowledge Base"
  type        = string
}

variable "memory_writer_lambda_arn" {
  description = "ARN of the memory writer Lambda function"
  type        = string
}

variable "memory_writer_lambda_name" {
  description = "Name of the memory writer Lambda function"
  type        = string
}

variable "session_summary_retention_days" {
  description = "Number of days to retain SESSION_SUMMARY data"
  type        = number
  default     = 30
}
