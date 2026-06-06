# ─────────────────────────────────────────────────────────────
# Database Module — Variables
# ─────────────────────────────────────────────────────────────
variable "project_name" { type = string }
variable "environment" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "aurora_security_group_id" { type = string }
variable "redis_security_group_id" { type = string }
variable "kms_aurora_key_arn" { type = string }

variable "aurora_engine_version" {
  type    = string
  default = "15.4"
}
variable "aurora_min_capacity" {
  description = "Aurora Serverless v2 minimum ACU"
  type        = number
  default     = 0.5
}
variable "aurora_max_capacity" {
  description = "Aurora Serverless v2 maximum ACU"
  type        = number
  default     = 4
}
variable "aurora_master_username" {
  type    = string
  default = "omniadmin"
}
variable "aurora_master_password_ssm" {
  description = "SSM parameter ARN for Aurora master password"
  type        = string
}
variable "redis_node_type" {
  type    = string
  default = "cache.r6g.large"
}
variable "redis_engine_version" {
  type    = string
  default = "7.1"
}
variable "redis_auth_token_ssm" {
  description = "SSM parameter ARN for Redis auth token"
  type        = string
}
variable "tags" {
  type    = map(string)
  default = {}
}
