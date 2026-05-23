output "bucket_id" {
  description = "S3 bucket ID for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "dynamodb_table_id" {
  description = "DynamoDB table ID for state locking"
  value       = aws_dynamodb_table.terraform_locks.id
}
