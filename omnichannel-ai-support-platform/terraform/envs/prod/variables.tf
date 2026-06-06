variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "environment" {
  type    = string
  default = "prod"
}
variable "project_name" {
  type    = string
  default = "omnipresense-ai"
}
variable "domain_name" {
  description = "Custom domain (leave empty to skip Route53)"
  type        = string
  default     = ""
}
variable "github_org_repo" {
  description = "GitHub org/repo for OIDC"
  type        = string
  default     = "pusnaik2016/OmniPresenseAI"
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
