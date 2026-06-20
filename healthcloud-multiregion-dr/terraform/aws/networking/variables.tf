variable "project" {
  description = "Project name"
  type        = string
  default     = "healthcloud"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azure_dr_cidr" {
  description = "Azure DR VNet CIDR for VPN routing"
  type        = string
  default     = ""
}

variable "vpn_gateway_id" {
  description = "VPN Gateway ID for cross-cloud routing"
  type        = string
  default     = ""
}

variable "flow_log_group_arn" {
  description = "CloudWatch Log Group ARN for VPC flow logs"
  type        = string
  default     = ""
}

variable "flow_log_role_arn" {
  description = "IAM Role ARN for VPC flow logs"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project    = "healthcloud"
    ManagedBy  = "terraform"
    Owner      = "platform-team"
    Compliance = "hipaa"
  }
}
