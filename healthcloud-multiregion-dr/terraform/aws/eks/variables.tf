variable "project"              { type = string; default = "healthcloud" }
variable "environment"          { type = string }
variable "kubernetes_version"   { type = string; default = "1.30" }
variable "vpc_id"               { type = string }
variable "vpc_cidr"             { type = string }
variable "private_subnet_ids"   { type = list(string) }
variable "kms_key_arn"          { type = string }
variable "allowed_cidrs"        { type = list(string); default = ["0.0.0.0/0"] }
variable "common_tags"          { type = map(string); default = {} }
