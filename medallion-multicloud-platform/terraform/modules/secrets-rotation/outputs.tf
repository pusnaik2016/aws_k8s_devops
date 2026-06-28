# Secrets Rotation Module — Outputs
output "rotation_lambda_arn" { value = aws_lambda_function.rotation.arn }
output "azure_function_app_id" { value = azurerm_linux_function_app.rotation.id }
output "azure_function_identity_principal_id" { value = azurerm_linux_function_app.rotation.identity[0].principal_id }
