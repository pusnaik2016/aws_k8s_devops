variable "prefix" {
  description = "Resource name prefix"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "enable_guardduty" {
  description = "Enable GuardDuty threat detection"
  type        = bool
  default     = true
}

variable "enable_dr" {
  description = "Enable Disaster Recovery resources"
  type        = bool
  default     = true
}

variable "db_instance_identifier" {
  description = "RDS instance identifier for event subscriptions and alarms"
  type        = string
}
