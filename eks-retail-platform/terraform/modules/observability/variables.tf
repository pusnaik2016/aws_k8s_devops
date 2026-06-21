variable "name_prefix" { type = string }
variable "cluster_name" { type = string }
variable "aws_region" { type = string }
variable "kms_key_arn" { type = string }
variable "log_retention_days" { type = number; default = 365 }
variable "oidc_provider_arn" { type = string }
variable "oidc_provider_url" { type = string }
variable "common_tags" { type = map(string); default = {} }
