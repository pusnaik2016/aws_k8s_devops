# ============================================================================
# Azure AKS — DR Kubernetes Cluster with Warm Standby
# ============================================================================

terraform {
  required_version = ">= 1.5"
}

resource "azurerm_resource_group" "aks" {
  name     = "${var.project}-${var.environment}-aks-rg"
  location = var.azure_region
  tags     = var.common_tags
}

resource "azurerm_kubernetes_cluster" "dr" {
  name                = "${var.project}-${var.environment}-aks"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  dns_prefix          = "${var.project}-${var.environment}"
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.environment == "prod" ? "Standard" : "Free"

  default_node_pool {
    name                = "system"
    vm_size             = var.environment == "prod" ? "Standard_D4s_v5" : "Standard_D2s_v5"
    node_count          = var.environment == "prod" ? 2 : 1  # Warm standby
    min_count           = var.environment == "prod" ? 2 : 1
    max_count           = var.environment == "prod" ? 8 : 3
    enable_auto_scaling = true
    vnet_subnet_id      = var.aks_subnet_id
    os_disk_size_gb     = 128
    max_pods            = 50

    node_labels = {
      environment = var.environment
      role        = "dr"
      compliance  = "hipaa"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "calico"
    load_balancer_sku = "standard"
    outbound_type     = "userAssignedNATGateway"
  }

  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  azure_active_directory_role_based_access_control {
    managed                = true
    azure_rbac_enabled     = true
  }

  tags = merge(var.common_tags, {
    Name               = "${var.project}-${var.environment}-aks"
    Role               = "dr"
    DataClassification = "phi"
    Compliance         = "hipaa"
  })
}

# ──────────────────────────────────────────────────────────────────────────────
# User Node Pool (for application workloads)
# ──────────────────────────────────────────────────────────────────────────────

resource "azurerm_kubernetes_cluster_node_pool" "apps" {
  name                  = "apps"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.dr.id
  vm_size               = var.environment == "prod" ? "Standard_D4s_v5" : "Standard_D2s_v5"
  node_count            = var.environment == "prod" ? 2 : 1
  min_count             = 1
  max_count             = var.environment == "prod" ? 10 : 3
  enable_auto_scaling   = true
  vnet_subnet_id        = var.aks_subnet_id

  node_labels = {
    workload   = "healthcare"
    compliance = "hipaa"
  }

  node_taints = ["dedicated=healthcare:NoSchedule"]

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-aks-apps-pool"
  })
}

# ──────────────────────────────────────────────────────────────────────────────
# ACR (Azure Container Registry)
# ──────────────────────────────────────────────────────────────────────────────

resource "azurerm_container_registry" "main" {
  name                = "${replace(var.project, "-", "")}${var.environment}acr"
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location
  sku                 = "Premium"
  admin_enabled       = false

  georeplications {
    location                = "westus2"
    zone_redundancy_enabled = true
  }

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-acr"
  })
}

resource "azurerm_role_assignment" "aks_acr" {
  principal_id                     = azurerm_kubernetes_cluster.dr.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.main.id
  skip_service_principal_aad_check = true
}
