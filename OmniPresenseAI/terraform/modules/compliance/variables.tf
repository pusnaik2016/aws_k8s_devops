# ─────────────────────────────────────────────────────────────
# Compliance Module — Variables
# ─────────────────────────────────────────────────────────────

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (prod, staging)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "kms_s3_key_arn" {
  description = "KMS key ARN for S3 encryption"
  type        = string
}

variable "alert_email" {
  description = "Email for compliance and budget alerts"
  type        = string
  default     = ""
}

variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD"
  type        = string
  default     = "700"
}

variable "transcripts_bucket_name" {
  description = "S3 bucket name for transcripts (Macie scanning)"
  type        = string
}

variable "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN for WAF association"
  type        = string
  default     = ""
}

variable "blocked_countries" {
  description = "Country codes to block/monitor in WAF"
  type        = list(string)
  default     = ["KP", "IR", "CU", "SY"] # OFAC sanctioned countries
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
