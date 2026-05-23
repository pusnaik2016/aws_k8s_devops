output "endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.postgres.endpoint
  sensitive   = true
}

output "db_name" {
  description = "RDS database name"
  value       = aws_db_instance.postgres.db_name
}

output "secret_arn" {
  description = "Secrets Manager ARN for database credentials"
  value       = aws_secretsmanager_secret.db_link.arn
  sensitive   = true
}

output "kms_key_arn" {
  description = "KMS key ARN for RDS/Secrets Manager encryption"
  value       = aws_kms_key.env_kms.arn
}

output "kms_key_id" {
  description = "KMS key ID"
  value       = aws_kms_key.env_kms.id
}

output "instance_identifier" {
  description = "RDS instance identifier"
  value       = aws_db_instance.postgres.identifier
}
