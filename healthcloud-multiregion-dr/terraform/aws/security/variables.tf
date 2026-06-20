variable "project"          { type = string; default = "healthcloud" }
variable "environment"      { type = string }
variable "aws_region"       { type = string; default = "us-east-1" }
variable "audit_bucket_name" { type = string }
variable "config_role_arn"  { type = string; default = "" }
variable "common_tags"      { type = map(string); default = {} }
