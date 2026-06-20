variable "project"        { type = string; default = "healthcloud" }
variable "environment"    { type = string }
variable "aws_region"     { type = string; default = "us-east-1" }
variable "kms_key_arn"    { type = string }
variable "alert_emails"   { type = list(string); default = [] }
variable "primary_domain" { type = string; default = "api.healthcloud.example.com" }
variable "common_tags"    { type = map(string); default = {} }
