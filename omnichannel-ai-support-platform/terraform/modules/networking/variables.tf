# ─────────────────────────────────────────────────────────────
# Networking Module — Variables
# ─────────────────────────────────────────────────────────────

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "omnipresense-ai"
}

variable "environment" {
  description = "Environment name (prod, staging, dev)"
  type        = string
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
}

variable "domain_name" {
  description = "Domain name for Route53 hosted zone"
  type        = string
  default     = ""
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs to CloudWatch"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway (cost optimization)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
