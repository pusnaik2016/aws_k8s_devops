# =============================================================================
# SECRETS ROTATION MODULE — Lambda + Azure Functions (90-day Policy)
# =============================================================================
# PCI-DSS/SOC 2: Automated 90-day rotation for all credentials
# AWS: Lambda function triggered by Secrets Manager rotation schedule
# Azure: Azure Function triggered by Key Vault SecretNearExpiry Event Grid
# =============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  tags = merge(var.common_tags, {
    Module = "secrets-rotation"; Compliance = "pci-dss-soc2"; ManagedBy = "terraform"
  })
}

# =============================================================================
# AWS LAMBDA — Secrets Rotation Function
# =============================================================================

data "archive_file" "rotation_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/rotate_secrets.py"
  output_path = "${path.module}/lambda/rotate_secrets.zip"
}

resource "aws_iam_role" "rotation_lambda" {
  name = "${local.name_prefix}-secrets-rotation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "rotation_lambda" {
  name = "${local.name_prefix}-secrets-rotation-policy"
  role = aws_iam_role.rotation_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage",
          "secretsmanager:DescribeSecret"
        ]
        Resource = var.secret_arns
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = [var.kms_key_arn]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = [var.sns_topic_arn]
      }
    ]
  })
}

resource "aws_lambda_function" "rotation" {
  function_name    = "${local.name_prefix}-secrets-rotation"
  filename         = data.archive_file.rotation_lambda.output_path
  source_code_hash = data.archive_file.rotation_lambda.output_base64sha256
  handler          = "rotate_secrets.lambda_handler"
  runtime          = "python3.12"
  timeout          = 300
  role             = aws_iam_role.rotation_lambda.arn

  environment {
    variables = {
      PROJECT_NAME = var.project_name
      ENVIRONMENT  = var.environment
      SNS_TOPIC    = var.sns_topic_arn
    }
  }

  tags = local.tags
}

resource "aws_lambda_permission" "secretsmanager" {
  statement_id  = "AllowSecretsManagerInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rotation.function_name
  principal     = "secretsmanager.amazonaws.com"
}

# Configure 90-day rotation on each secret
resource "aws_secretsmanager_secret_rotation" "automated" {
  for_each = toset(var.secret_arns)

  secret_id           = each.value
  rotation_lambda_arn = aws_lambda_function.rotation.arn

  rotation_rules {
    automatically_after_days = 90
  }
}

# =============================================================================
# AZURE FUNCTION — Key Vault Secret Rotation
# =============================================================================
resource "azurerm_resource_group" "rotation" {
  name     = "${local.name_prefix}-rotation-rg"
  location = var.azure_location
  tags     = local.tags
}

resource "azurerm_storage_account" "function_storage" {
  name                     = replace(lower("${local.name_prefix}rotfn"), "-", "")
  location                 = azurerm_resource_group.rotation.location
  resource_group_name      = azurerm_resource_group.rotation.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  tags = local.tags
}

resource "azurerm_service_plan" "rotation" {
  name                = "${local.name_prefix}-rotation-plan"
  location            = azurerm_resource_group.rotation.location
  resource_group_name = azurerm_resource_group.rotation.name
  os_type             = "Linux"
  sku_name            = "Y1" # Consumption plan

  tags = local.tags
}

resource "azurerm_linux_function_app" "rotation" {
  name                       = "${local.name_prefix}-secret-rotation"
  location                   = azurerm_resource_group.rotation.location
  resource_group_name        = azurerm_resource_group.rotation.name
  service_plan_id            = azurerm_service_plan.rotation.id
  storage_account_name       = azurerm_storage_account.function_storage.name
  storage_account_access_key = azurerm_storage_account.function_storage.primary_access_key

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      python_version = "3.11"
    }
  }

  app_settings = {
    KEY_VAULT_NAME                     = var.key_vault_name
    AzureWebJobsFeatureFlags           = "EnableWorkerIndexing"
    FUNCTIONS_WORKER_RUNTIME           = "python"
    SCM_DO_BUILD_DURING_DEPLOYMENT     = "true"
  }

  tags = local.tags
}

# Grant Function App access to Key Vault
resource "azurerm_role_assignment" "function_keyvault" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = azurerm_linux_function_app.rotation.identity[0].principal_id
}

# Event Grid subscription for SecretNearExpiry events
resource "azurerm_eventgrid_system_topic" "keyvault" {
  name                   = "${local.name_prefix}-kv-events"
  location               = azurerm_resource_group.rotation.location
  resource_group_name    = azurerm_resource_group.rotation.name
  source_arm_resource_id = var.key_vault_id
  topic_type             = "Microsoft.KeyVault.vaults"

  tags = local.tags
}

resource "azurerm_eventgrid_system_topic_event_subscription" "secret_expiry" {
  name                = "${local.name_prefix}-secret-expiry"
  system_topic        = azurerm_eventgrid_system_topic.keyvault.name
  resource_group_name = azurerm_resource_group.rotation.name

  azure_function_endpoint {
    function_id = "${azurerm_linux_function_app.rotation.id}/functions/SecretRotationFunction"
  }

  included_event_types = [
    "Microsoft.KeyVault.SecretNearExpiry"
  ]
}
