# =============================================================================
# Production Environment Configuration
# =============================================================================

project_name = "iot-greengrass"
environment  = "prod"
aws_region   = "us-east-1"

# IoT Configuration
customer_sites              = ["site-mumbai", "site-bangalore", "site-delhi"]
telemetry_topic_prefix      = "dt/iot-greengrass"
alert_temperature_threshold = 35.0
alert_humidity_threshold    = 85.0

# Notification
alert_email = "" # Set your email to receive alerts

# Timestream Retention (prod = full retention)
timestream_memory_retention_hours  = 24
timestream_magnetic_retention_days = 365

# S3 Lifecycle (prod = 7-year compliance)
s3_transition_ia_days      = 30
s3_transition_glacier_days = 90
s3_expiration_days         = 2555
