variable "enable" {
  description = "Enable External Secrets Operator"
  type        = bool
  default     = true
}

variable "chart_version" {
  description = "External Secrets Helm chart version"
  type        = string
  default     = "0.10.7"
}

variable "prefix" {
  description = "Resource name prefix"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "oidc_provider_arn" {
  description = "EKS OIDC provider ARN"
  type        = string
}

variable "oidc_provider" {
  description = "EKS OIDC provider URL (without https://)"
  type        = string
}

variable "db_secret_arn" {
  description = "Secrets Manager ARN for database credentials"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for decryption"
  type        = string
}
