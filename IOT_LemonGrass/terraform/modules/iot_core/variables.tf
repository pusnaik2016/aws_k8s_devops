# -----------------------------------------------------------------------------
# IoT Core Module — Variables
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
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

variable "customer_sites" {
  description = "List of customer site names"
  type        = list(string)
}

variable "telemetry_topic_prefix" {
  description = "MQTT topic prefix for telemetry data"
  type        = string
}
