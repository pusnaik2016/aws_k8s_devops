# ==============================================================================
# VPC Module — Input Variables
# ==============================================================================

variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
}

variable "aws_region" {
  description = "AWS region for VPC endpoint service names"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of AZs for multi-AZ deployment (minimum 3)"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks for database subnets (one per AZ)"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway (dev) vs one per AZ (prod HA)"
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "KMS key ARN for encrypting VPC Flow Logs CloudWatch LogGroup"
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all VPC resources"
  type        = map(string)
  default     = {}
}
