###############################################################################
# Bedrock Config Module — Variables
###############################################################################

variable "model_id" {
  description = "Amazon Bedrock model ID (must be enabled in your account first)."
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20241022-v2:0"
}

variable "aws_region" {
  description = "AWS region where Bedrock will be invoked."
  type        = string
}
