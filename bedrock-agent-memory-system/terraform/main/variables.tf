variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "agentcore-memory"
}

variable "aurora_master_password" {
  description = "Master password for Aurora PostgreSQL cluster"
  type        = string
  sensitive   = true
}

variable "aurora_min_capacity" {
  description = "Minimum ACU for Aurora Serverless v2 (0.5 = ~$43/mo)"
  type        = number
  default     = 0.5
}

variable "aurora_max_capacity" {
  description = "Maximum ACU for Aurora Serverless v2"
  type        = number
  default     = 4
}

variable "foundation_model" {
  description = "Bedrock foundation model (do NOT use eu. prefix for agents)"
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20241022-v2:0"
}

variable "confidence_threshold" {
  description = "Minimum confidence to persist a fact (0.0-1.0)"
  type        = number
  default     = 0.7

  validation {
    condition     = var.confidence_threshold >= 0 && var.confidence_threshold <= 1
    error_message = "Confidence threshold must be between 0.0 and 1.0."
  }
}
