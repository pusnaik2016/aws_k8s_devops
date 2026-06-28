# Secrets Rotation Module — Variables
variable "project_name" { type = string }
variable "environment" { type = string }
variable "common_tags" { type = map(string); default = {} }
variable "azure_location" { type = string; default = "eastus2" }
variable "secret_arns" { description = "AWS Secrets Manager secret ARNs to rotate"; type = list(string) }
variable "kms_key_arn" { description = "KMS key ARN for secret decryption"; type = string }
variable "sns_topic_arn" { description = "SNS topic ARN for rotation notifications"; type = string }
variable "key_vault_id" { description = "Azure Key Vault resource ID"; type = string }
variable "key_vault_name" { description = "Azure Key Vault name"; type = string }
