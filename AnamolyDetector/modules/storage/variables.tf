###############################################################################
# Storage Module — Variables
###############################################################################

variable "table_name" {
  description = "Base name for the DynamoDB table (environment suffix appended)."
  type        = string
  default     = "cost-history"
}

variable "retention_days" {
  description = "Number of days to retain cost history rows (via TTL)."
  type        = number
  default     = 90
}

variable "environment" {
  description = "Deployment environment label."
  type        = string
}
