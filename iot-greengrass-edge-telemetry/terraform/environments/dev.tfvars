# =============================================================================
# Development Environment Configuration
# =============================================================================

project_name = "iot-greengrass"
environment  = "dev"
aws_region   = "us-east-1"

# IoT Configuration
customer_sites              = ["site-mumbai", "site-bangalore", "site-delhi"]
telemetry_topic_prefix      = "dt/iot-greengrass"
alert_temperature_threshold = 35.0
alert_humidity_threshold    = 85.0

# Notification
alert_email = "" # Set your email to receive alerts

# Timestream Retention (dev = shorter retention for cost savings)
timestream_memory_retention_hours  = 6
timestream_magnetic_retention_days = 30

# S3 Lifecycle (dev = shorter lifecycle)
s3_transition_ia_days      = 14
s3_transition_glacier_days = 60
s3_expiration_days         = 365
