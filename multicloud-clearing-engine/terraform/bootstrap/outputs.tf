# =============================================================================
# BOOTSTRAP — Outputs
# =============================================================================
# After running this bootstrap, use these values to configure the backend
# blocks in terraform/environments/production/providers.tf
# =============================================================================

# --- AWS State Backend ---
output "aws_s3_bucket" {
  description = "S3 bucket name for Terraform state"
  value       = aws_s3_bucket.tfstate.id
}

output "aws_dynamodb_table" {
  description = "DynamoDB table name for state locking"
  value       = aws_dynamodb_table.tflock.name
}

output "aws_backend_config" {
  description = "Copy this to your providers.tf backend block"
  value = <<-EOT
    backend "s3" {
      bucket         = "${aws_s3_bucket.tfstate.id}"
      key            = "multicloud/prod.tfstate"
      region         = "${var.aws_region}"
      dynamodb_table = "${aws_dynamodb_table.tflock.name}"
      encrypt        = true
    }
  EOT
}

# --- Azure State Backend ---
output "azure_resource_group" {
  description = "Azure resource group containing the state storage"
  value       = azurerm_resource_group.tfstate.name
}

output "azure_storage_account" {
  description = "Azure storage account name for state"
  value       = azurerm_storage_account.tfstate.name
}

output "azure_container" {
  description = "Azure blob container for state"
  value       = azurerm_storage_container.tfstate.name
}

output "azure_backend_config" {
  description = "Alternative Azure backend config (if switching from S3)"
  value = <<-EOT
    # Alternative: Azure backend
    # backend "azurerm" {
    #   resource_group_name  = "${azurerm_resource_group.tfstate.name}"
    #   storage_account_name = "${azurerm_storage_account.tfstate.name}"
    #   container_name       = "${azurerm_storage_container.tfstate.name}"
    #   key                  = "multicloud/prod.tfstate"
    # }
  EOT
}

# --- GCP State Backend ---
output "gcp_bucket" {
  description = "GCS bucket name for state"
  value       = google_storage_bucket.tfstate.name
}

output "gcp_backend_config" {
  description = "Alternative GCS backend config (if switching from S3)"
  value = <<-EOT
    # Alternative: GCS backend
    # backend "gcs" {
    #   bucket = "${google_storage_bucket.tfstate.name}"
    #   prefix = "multicloud/prod"
    # }
  EOT
}
