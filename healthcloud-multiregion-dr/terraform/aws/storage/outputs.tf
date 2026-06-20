output "phi_bucket_arn"          { value = aws_s3_bucket.phi_data.arn }
output "phi_bucket_name"         { value = aws_s3_bucket.phi_data.id }
output "audit_bucket_arn"        { value = aws_s3_bucket.audit_logs.arn }
output "audit_bucket_name"       { value = aws_s3_bucket.audit_logs.id }
output "static_bucket_name"      { value = aws_s3_bucket.static_assets.id }
output "cloudfront_domain"       { value = aws_cloudfront_distribution.main.domain_name }
output "cloudfront_distribution_id" { value = aws_cloudfront_distribution.main.id }
