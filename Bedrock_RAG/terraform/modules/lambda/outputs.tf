output "chat_function_arn" {
  value = aws_lambda_function.chat.arn
}

output "chat_function_name" {
  value = aws_lambda_function.chat.function_name
}

output "ingest_function_arn" {
  value = aws_lambda_function.ingest.arn
}
