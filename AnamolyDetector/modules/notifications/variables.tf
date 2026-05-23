###############################################################################
# Notifications Module — Variables
###############################################################################

variable "topic_name" {
  description = "Base name for the SNS topic."
  type        = string
  default     = "cost-anomaly-alerts"
}

variable "alert_email" {
  description = "Email address to subscribe to the SNS topic."
  type        = string
}

variable "environment" {
  description = "Deployment environment label."
  type        = string
}
