# ==============================================================================
# CloudWatch Module — Variables
# ==============================================================================
variable "project_name" { type = string }
variable "aws_region" { type = string }
variable "kms_key_arn" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}
