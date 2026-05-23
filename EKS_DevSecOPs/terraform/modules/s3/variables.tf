# ==============================================================================
# S3 Module — Variables
# ==============================================================================
variable "project_name" { type = string }
variable "aws_region" { type = string }
variable "account_id" { type = string }
variable "bucket_purpose" {
  description = "Purpose suffix for the bucket name (e.g., audit-logs, artifacts)"
  type        = string
}
variable "kms_key_arn" { type = string }
variable "retention_days" {
  description = "Number of days before objects expire"
  type        = number
  default     = 2555  # 7 years
}
variable "force_destroy" {
  type    = bool
  default = false
}
variable "tags" {
  type    = map(string)
  default = {}
}
