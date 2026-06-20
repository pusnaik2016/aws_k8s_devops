variable "project"            { type = string; default = "healthcloud" }
variable "environment"        { type = string }
variable "vpc_id"             { type = string }
variable "database_subnet_ids" { type = list(string) }
variable "eks_sg_id"          { type = string }
variable "kms_key_arn"        { type = string }
variable "db_master_username" { type = string; sensitive = true; default = "healthcloud_admin" }
variable "db_master_password" { type = string; sensitive = true }
variable "redis_auth_token"   { type = string; sensitive = true }
variable "common_tags"        { type = map(string); default = {} }
