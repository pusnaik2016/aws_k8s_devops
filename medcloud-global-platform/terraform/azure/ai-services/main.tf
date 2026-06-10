# ─────────────────────────────────────────────────────────────────────────────
# Azure AI Services — Azure OpenAI + AI Vision for Medical Processing
# ─────────────────────────────────────────────────────────────────────────────
# - Azure OpenAI: Clinical note summarization, entity extraction
# - Azure AI Vision: Medical image (DICOM) analysis
# - Private endpoints for all AI services (HIPAA)
# - Content filtering enabled
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
  }

  backend "azurerm" {
    resource_group_name  = "medcloud-terraform-state-rg"
    storage_account_name = "medcloudtfstate"
    container_name       = "tfstate"
    key                  = "azure/ai-services/terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

data "terraform_remote_state" "networking" {
  backend = "azurerm"
  config = {
    resource_group_name  = "medcloud-terraform-state-rg"
    storage_account_name = "medcloudtfstate"
    container_name       = "tfstate"
    key                  = "azure/networking/terraform.tfstate"
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  location    = var.azure_location
  pe_subnet   = data.terraform_remote_state.networking.outputs.private_endpoints_subnet_id
}

resource "azurerm_resource_group" "ai" {
  name     = "${local.name_prefix}-ai-services-rg"
  location = local.location
  tags     = merge(var.common_tags, { Component = "ai-services" })
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Azure OpenAI Service — Clinical NLP
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

resource "azurerm_cognitive_account" "openai" {
  name                          = "${local.name_prefix}-openai"
  location                      = local.location
  resource_group_name           = azurerm_resource_group.ai.name
  kind                          = "OpenAI"
  sku_name                      = "S0"
  public_network_access_enabled = false
  custom_subdomain_name         = "${local.name_prefix}-openai"

  network_acls {
    default_action = "Deny"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = merge(var.common_tags, {
    Compliance = "HIPAA"
    Service    = "azure-openai"
  })
}

# GPT-4o deployment for clinical note processing
resource "azurerm_cognitive_deployment" "gpt4o" {
  name                 = "gpt-4o-clinical"
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = "gpt-4o"
    version = "2024-05-13"
  }

  scale {
    type     = "Standard"
    capacity = var.environment == "prod" ? 30 : 10 # TPM in thousands
  }
}

# Text embedding for medical document search (RAG)
resource "azurerm_cognitive_deployment" "embedding" {
  name                 = "text-embedding-ada"
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = "text-embedding-ada-002"
    version = "2"
  }

  scale {
    type     = "Standard"
    capacity = var.environment == "prod" ? 60 : 20
  }
}

# Private endpoint for Azure OpenAI
resource "azurerm_private_endpoint" "openai" {
  name                = "${local.name_prefix}-openai-pe"
  location            = azurerm_resource_group.ai.location
  resource_group_name = azurerm_resource_group.ai.name
  subnet_id           = local.pe_subnet

  private_service_connection {
    name                           = "${local.name_prefix}-openai-psc"
    private_connection_resource_id = azurerm_cognitive_account.openai.id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }

  tags = var.common_tags
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Azure AI Vision — Medical Image Analysis
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

resource "azurerm_cognitive_account" "vision" {
  name                          = "${local.name_prefix}-ai-vision"
  location                      = local.location
  resource_group_name           = azurerm_resource_group.ai.name
  kind                          = "ComputerVision"
  sku_name                      = "S1"
  public_network_access_enabled = false
  custom_subdomain_name         = "${local.name_prefix}-vision"

  network_acls {
    default_action = "Deny"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = merge(var.common_tags, {
    Compliance = "HIPAA"
    Service    = "ai-vision"
  })
}

# Private endpoint for AI Vision
resource "azurerm_private_endpoint" "vision" {
  name                = "${local.name_prefix}-vision-pe"
  location            = azurerm_resource_group.ai.location
  resource_group_name = azurerm_resource_group.ai.name
  subnet_id           = local.pe_subnet

  private_service_connection {
    name                           = "${local.name_prefix}-vision-psc"
    private_connection_resource_id = azurerm_cognitive_account.vision.id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }

  tags = var.common_tags
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Azure AI Search — RAG for Medical Knowledge Base
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

resource "azurerm_search_service" "main" {
  name                          = "${local.name_prefix}-ai-search"
  resource_group_name           = azurerm_resource_group.ai.name
  location                      = azurerm_resource_group.ai.location
  sku                           = var.environment == "prod" ? "standard" : "basic"
  public_network_access_enabled = false
  replica_count                 = var.environment == "prod" ? 3 : 1
  partition_count               = var.environment == "prod" ? 2 : 1

  identity {
    type = "SystemAssigned"
  }

  tags = merge(var.common_tags, {
    Service = "ai-search"
  })
}

# ─── Blob Storage for Medical Images (DICOM) ────────────────────────────────

resource "azurerm_storage_account" "medical_images" {
  name                            = replace("${local.name_prefix}medimages", "-", "")
  resource_group_name             = azurerm_resource_group.ai.name
  location                        = azurerm_resource_group.ai.location
  account_tier                    = "Standard"
  account_replication_type        = var.environment == "prod" ? "GRS" : "LRS"
  min_tls_version                 = "TLS1_2"
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled  = true
    change_feed_enabled = true

    delete_retention_policy {
      days = var.environment == "prod" ? 365 : 30
    }

    container_delete_retention_policy {
      days = 14
    }
  }

  identity {
    type = "SystemAssigned"
  }

  tags = merge(var.common_tags, {
    Compliance = "HIPAA"
    DataClass  = "PHI-DICOM"
  })
}

resource "azurerm_storage_container" "dicom_images" {
  name                  = "dicom-images"
  storage_account_name  = azurerm_storage_account.medical_images.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "ehr_documents" {
  name                  = "ehr-documents"
  storage_account_name  = azurerm_storage_account.medical_images.name
  container_access_type = "private"
}

# ─── Outputs ─────────────────────────────────────────────────────────────────

output "openai_endpoint" {
  value = azurerm_cognitive_account.openai.endpoint
}

output "openai_id" {
  value = azurerm_cognitive_account.openai.id
}

output "vision_endpoint" {
  value = azurerm_cognitive_account.vision.endpoint
}

output "ai_search_endpoint" {
  value = "https://${azurerm_search_service.main.name}.search.windows.net"
}

output "medical_images_storage_id" {
  value = azurerm_storage_account.medical_images.id
}
