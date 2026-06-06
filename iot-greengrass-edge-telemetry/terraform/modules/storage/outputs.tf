# -----------------------------------------------------------------------------
# Storage Module — Outputs
# -----------------------------------------------------------------------------

output "s3_bucket_arn" {
  description = "ARN of the telemetry S3 bucket"
  value       = aws_s3_bucket.telemetry.arn
}

output "s3_bucket_name" {
  description = "Name of the telemetry S3 bucket"
  value       = aws_s3_bucket.telemetry.id
}

output "timestream_database_name" {
  description = "Timestream database name"
  value       = aws_timestreamwrite_database.telemetry.database_name
}

output "timestream_database_arn" {
  description = "Timestream database ARN"
  value       = aws_timestreamwrite_database.telemetry.arn
}

output "timestream_table_name" {
  description = "Timestream table name"
  value       = aws_timestreamwrite_table.sensor_data.table_name
}

output "timestream_table_arn" {
  description = "Timestream table ARN"
  value       = aws_timestreamwrite_table.sensor_data.arn
}
