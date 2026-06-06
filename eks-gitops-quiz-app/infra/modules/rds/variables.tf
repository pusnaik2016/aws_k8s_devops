variable "prefix" {
  description = "Resource name prefix"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for RDS subnets and security group"
  type        = string
}

variable "availability_zones" {
  description = "Availability zones for RDS subnets"
  type        = list(string)
}

variable "db_settings" {
  description = "RDS PostgreSQL database configuration"
  type = object({
    allocated_storage       = number
    max_allocated_storage   = number
    engine_version          = number
    instance_class          = string
    backup_retention_period = number
    db_name                 = string
    ca_cert_name            = string
    db_admin_username       = string
  })
}

variable "enable_dr" {
  description = "Whether DR is enabled (used for tagging)"
  type        = bool
  default     = true
}
