# -----------------------------------------------------------------------------
# General
# -----------------------------------------------------------------------------
variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "bedrock-rag"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

# -----------------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# -----------------------------------------------------------------------------
# Bedrock
# -----------------------------------------------------------------------------
variable "bedrock_model_id" {
  description = "Bedrock foundation model ID for text generation"
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20241022-v2:0"
}

variable "embedding_model_id" {
  description = "Bedrock embedding model ID for vector generation"
  type        = string
  default     = "amazon.titan-embed-text-v2:0"
}
