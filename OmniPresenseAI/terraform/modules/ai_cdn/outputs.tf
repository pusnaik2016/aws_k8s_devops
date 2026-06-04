output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.main.id
}
output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.main.domain_name
}
output "frontend_bucket_arn" {
  value = aws_s3_bucket.frontend.arn
}
output "frontend_bucket_name" {
  value = aws_s3_bucket.frontend.id
}
output "transcripts_bucket_arn" {
  value = aws_s3_bucket.transcripts.arn
}
output "transcripts_bucket_name" {
  value = aws_s3_bucket.transcripts.id
}
output "websocket_api_endpoint" {
  value = aws_apigatewayv2_stage.websocket.invoke_url
}
output "rest_api_endpoint" {
  value = aws_apigatewayv2_stage.rest.invoke_url
}
