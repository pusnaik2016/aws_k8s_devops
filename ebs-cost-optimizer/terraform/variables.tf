###############################################################################
# Variables
###############################################################################

variable "aws_region" {
  description = "AWS region to deploy the scheduler stack."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment (prod, staging, dev)."
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["prod", "staging", "dev"], var.environment)
    error_message = "environment must be one of: prod, staging, dev."
  }
}

variable "alert_email" {
  description = "Email address for the nightly cost-savings digest (leave blank to skip)."
  type        = string
  default     = ""
}

variable "lambda_dry_run" {
  description = "When true the Lambda will tag in dry-run mode (no AWS changes)."
  type        = bool
  default     = false
}

variable "config_yaml_base64" {
  description = <<-EOT
    Base64-encoded content of config.yaml, injected as a Lambda environment
    variable so no S3 bucket or layer is needed.

    Generate with:
      base64 -i config.yaml
  EOT
  type      = string
  sensitive = true
  default   = ""
}
