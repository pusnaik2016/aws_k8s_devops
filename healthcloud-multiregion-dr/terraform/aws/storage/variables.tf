variable "project"           { type = string; default = "healthcloud" }
variable "environment"       { type = string }
variable "aws_account_id"   { type = string }
variable "kms_key_arn"       { type = string }
variable "waf_acl_arn"       { type = string; default = "" }
variable "allowed_countries" { type = list(string); default = ["US", "IN", "GB", "DE"] }
variable "common_tags"       { type = map(string); default = {} }
