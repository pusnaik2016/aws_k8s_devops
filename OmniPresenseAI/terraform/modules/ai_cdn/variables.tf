variable "project_name" { type = string }
variable "environment" { type = string }
variable "aws_region" { type = string; default = "us-east-1" }
variable "domain_name" { type = string; default = "" }
variable "route53_zone_id" { type = string; default = "" }
variable "kms_s3_key_arn" { type = string }
variable "alb_dns_name" { type = string; default = "" }
variable "tags" { type = map(string); default = {} }
