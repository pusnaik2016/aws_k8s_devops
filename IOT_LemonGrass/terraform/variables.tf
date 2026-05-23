# -----------------------------------------------------------------------------
# Root-Level Input Variables
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Name of the project — used as prefix for all resource names"
  type        = string
  default     = "iot-greengrass"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

# -----------------------------------------------------------------------------
# IoT Configuration
# -----------------------------------------------------------------------------
variable "customer_sites" {
  description = "List of customer site names for device simulation"
  type        = list(string)
  default     = ["site-mumbai", "site-bangalore", "site-delhi"]
}

variable "telemetry_topic_prefix" {
  description = "MQTT topic prefix for telemetry data"
  type        = string
  default     = "dt/iot-greengrass"
}

variable "alert_temperature_threshold" {
  description = "Temperature threshold (°C) for triggering alerts"
  type        = number
  default     = 35.0
}

variable "alert_humidity_threshold" {
  description = "Humidity threshold (%) for triggering alerts"
  type        = number
  default     = 85.0
}

# -----------------------------------------------------------------------------
# Notification
# -----------------------------------------------------------------------------
variable "alert_email" {
  description = "Email address for IoT alert notifications"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Timestream Configuration
# -----------------------------------------------------------------------------
variable "timestream_memory_retention_hours" {
  description = "Hours to retain data in Timestream memory store"
  type        = number
  default     = 24
}

variable "timestream_magnetic_retention_days" {
  description = "Days to retain data in Timestream magnetic store"
  type        = number
  default     = 365
}

# -----------------------------------------------------------------------------
# S3 Configuration
# -----------------------------------------------------------------------------
variable "s3_transition_ia_days" {
  description = "Days before transitioning S3 objects to Infrequent Access"
  type        = number
  default     = 30
}

variable "s3_transition_glacier_days" {
  description = "Days before transitioning S3 objects to Glacier"
  type        = number
  default     = 90
}

variable "s3_expiration_days" {
  description = "Days before expiring S3 objects"
  type        = number
  default     = 2555 # ~7 years
}
