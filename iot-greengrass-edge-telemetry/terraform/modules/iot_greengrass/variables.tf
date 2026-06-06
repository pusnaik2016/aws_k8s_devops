# -----------------------------------------------------------------------------
# IoT Greengrass Module — Variables
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "greengrass_tes_role_arn" {
  description = "ARN of the IAM role for Greengrass Token Exchange Service"
  type        = string
}

variable "certificate_arns" {
  description = "Map of customer site to certificate ARN"
  type        = map(string)
}

variable "thing_group_arn" {
  description = "ARN of the IoT Thing Group for deployments"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for log encryption"
  type        = string
}
