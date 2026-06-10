# ─────────────────────────────────────────────────────────────────────────────
# Azure AKS Cluster — Medical & AI Services Compute
# ─────────────────────────────────────────────────────────────────────────────
# HIPAA-compliant AKS with:
# - Azure AD (Entra ID) RBAC integration
# - Azure CNI networking (pod-level NSG support)
# - Managed Istio service mesh add-on
# - Azure Key Vault Secrets Provider
# - Defender for Containers enabled
# - Private cluster in production
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
    key                  = "azure/aks/terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

# ─── Data Sources ────────────────────────────────────────────────────────────

data "terraform_remote_state" "networking" {
  backend = "azurerm"
  config = {
    resource_group_name  = "medcloud-terraform-state-rg"
    storage_account_name = "medcloudtfstate"
    container_name       = "tfstate"
    key                  = "azure/networking/terraform.tfstate"
  }
}

data "azurerm_client_config" "current" {}

# ─── Locals ──────────────────────────────────────────────────────────────────

locals {
  name_prefix  = "${var.project_name}-${var.environment}"
  cluster_name = "${local.name_prefix}-aks"
  location     = var.azure_location
  rg_name      = data.terraform_remote_state.networking.outputs.resource_group_name
  aks_subnet   = data.terraform_remote_state.networking.outputs.aks_subnet_id
  law_id       = data.terraform_remote_state.networking.outputs.log_analytics_workspace_id
}

# ─── Resource Group ──────────────────────────────────────────────────────────

resource "azurerm_resource_group" "aks" {
  name     = "${local.name_prefix}-aks-rg"
  location = local.location

  tags = merge(var.common_tags, {
    Cloud     = "Azure"
    Component = "aks"
  })
}

# ─── User Assigned Identity for AKS ─────────────────────────────────────────

resource "azurerm_user_assigned_identity" "aks" {
  name                = "${local.cluster_name}-identity"
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location

  tags = var.common_tags
}

# ─── AKS Cluster ────────────────────────────────────────────────────────────

resource "azurerm_kubernetes_cluster" "main" {
  name                = local.cluster_name
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  dns_prefix          = local.cluster_name
  kubernetes_version  = var.kubernetes_version

  # HIPAA: Private cluster in production
  private_cluster_enabled = var.environment == "prod" ? true : false
  sku_tier                = var.environment == "prod" ? "Standard" : "Free"

  # Azure CNI for pod-level networking
  network_profile {
    network_plugin    = "azure"
    network_policy    = "calico"
    service_cidr      = "10.101.0.0/16"
    dns_service_ip    = "10.101.0.10"
    load_balancer_sku = "standard"
    outbound_type     = "userDefinedRouting" # Route through Azure Firewall
  }

  # System node pool
  default_node_pool {
    name                 = "system"
    vm_size              = "Standard_D4s_v5"
    vnet_subnet_id       = local.aks_subnet
    min_count            = 2
    max_count            = 4
    enable_auto_scaling  = true
    os_disk_size_gb      = 100
    os_disk_type         = "Managed"
    max_pods             = 50
    type                 = "VirtualMachineScaleSets"
    zones                = ["1", "2", "3"]

    node_labels = {
      role  = "system"
      cloud = "azure"
    }

    only_critical_addons_enabled = true

    upgrade_settings {
      max_surge = "33%"
    }

    tags = merge(var.common_tags, {
      NodePool = "system"
    })
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  # Azure AD (Entra ID) RBAC integration
  azure_active_directory_role_based_access_control {
    managed                = true
    azure_rbac_enabled     = true
    tenant_id              = data.azurerm_client_config.current.tenant_id
  }

  # HIPAA: Enable monitoring
  oms_agent {
    log_analytics_workspace_id = local.law_id
  }

  # Microsoft Defender for Containers
  microsoft_defender {
    log_analytics_workspace_id = local.law_id
  }

  # Azure Key Vault Secrets Provider
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  # Managed Istio service mesh add-on
  service_mesh_profile {
    mode                             = "Istio"
    internal_ingress_gateway_enabled = true
    external_ingress_gateway_enabled = true
  }

  # HIPAA: Image cleaner to remove unused images (security)
  image_cleaner_enabled        = true
  image_cleaner_interval_hours = 24

  # Workload identity (IRSA equivalent)
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # Auto-upgrade channel
  automatic_channel_upgrade = var.environment == "prod" ? "stable" : "rapid"

  tags = merge(var.common_tags, {
    Compliance = "HIPAA,GDPR"
    Cluster    = local.cluster_name
  })
}

# ─── Application Node Pool (Medical & AI Workloads) ─────────────────────────

resource "azurerm_kubernetes_cluster_node_pool" "medical" {
  name                  = "medical"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.node_instance_type.azure
  vnet_subnet_id        = local.aks_subnet
  min_count             = var.node_count.min
  max_count             = var.node_count.max
  enable_auto_scaling   = true
  os_disk_size_gb       = 128
  os_disk_type          = "Managed"
  max_pods              = 50
  zones                 = ["1", "2", "3"]
  priority              = var.environment == "prod" ? "Regular" : "Spot"
  eviction_policy       = var.environment == "prod" ? null : "Delete"
  spot_max_price        = var.environment == "prod" ? null : -1

  node_labels = {
    role       = "medical"
    cloud      = "azure"
    workload   = "healthcare"
    compliance = "hipaa"
  }

  node_taints = [
    "workload=healthcare:NoSchedule"
  ]

  upgrade_settings {
    max_surge = "25%"
  }

  tags = merge(var.common_tags, {
    NodePool = "medical"
  })
}

# ─── GPU Node Pool (AI/ML — Azure OpenAI backend processing) ────────────────

resource "azurerm_kubernetes_cluster_node_pool" "gpu" {
  count = var.environment == "prod" ? 1 : 0

  name                  = "gpu"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = "Standard_NC6s_v3" # NVIDIA V100
  vnet_subnet_id        = local.aks_subnet
  min_count             = 0
  max_count             = 3
  enable_auto_scaling   = true
  os_disk_size_gb       = 256
  max_pods              = 30
  zones                 = ["1", "2"]

  node_labels = {
    role       = "gpu"
    cloud      = "azure"
    workload   = "ai-ml"
    gpu        = "nvidia-v100"
  }

  node_taints = [
    "nvidia.com/gpu=present:NoSchedule"
  ]

  tags = merge(var.common_tags, {
    NodePool = "gpu"
  })
}

# ─── Outputs ─────────────────────────────────────────────────────────────────

output "cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.main.name
}

output "cluster_id" {
  description = "AKS cluster ID"
  value       = azurerm_kubernetes_cluster.main.id
}

output "kube_config" {
  description = "AKS kubeconfig"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

output "oidc_issuer_url" {
  description = "AKS OIDC issuer URL for workload identity"
  value       = azurerm_kubernetes_cluster.main.oidc_issuer_url
}

output "kubelet_identity" {
  description = "AKS kubelet managed identity"
  value       = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}
