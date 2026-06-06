# -----------------------------------------------------------------------------
# IoT Rules Module — Variables
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "telemetry_topic_prefix" {
  description = "MQTT topic prefix"
  type        = string
}

variable "iot_rules_role_arn" {
  description = "IAM role ARN for IoT Rules Engine"
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 bucket name for telemetry archive"
  type        = string
}

variable "timestream_database_name" {
  description = "Timestream database name"
  type        = string
}

variable "timestream_table_name" {
  description = "Timestream table name"
  type        = string
}

variable "alert_lambda_arn" {
  description = "ARN of the alert processor Lambda"
  type        = string
}

variable "alert_temperature_threshold" {
  description = "Temperature threshold for alerts (°C)"
  type        = number
  default     = 35.0
}

variable "alert_humidity_threshold" {
  description = "Humidity threshold for alerts (%)"
  type        = number
  default     = 85.0
}
