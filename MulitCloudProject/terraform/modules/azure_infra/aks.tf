# =============================================================================
# AZURE AKS — Kubernetes Orchestration (Hot Standby Compute)
# =============================================================================

resource "azurerm_kubernetes_cluster" "main" {
  name                = "${local.name_prefix}-aks"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${var.project_name}-aks"
  kubernetes_version  = "1.30"

  # Private cluster with authorized IPs
  private_cluster_enabled = false # Set true for full private; requires bastion
  sku_tier                = "Standard"

  # Identity
  identity {
    type = "SystemAssigned"
  }

  # Azure AD RBAC Integration
  azure_active_directory_role_based_access_control {
    managed                = true
    azure_rbac_enabled     = true
    tenant_id              = var.azure_tenant_id
    admin_group_object_ids = [azuread_group.admins.object_id]
  }

  # System Node Pool
  default_node_pool {
    name                 = "system"
    vm_size              = var.aks_node_vm_size
    vnet_subnet_id       = azurerm_subnet.aks_system.id
    min_count            = var.aks_system_node_min
    max_count            = var.aks_system_node_max
    enable_auto_scaling  = true
    os_disk_size_gb      = 128
    os_disk_type         = "Managed"
    max_pods             = 110
    type                 = "VirtualMachineScaleSets"
    zones                = ["1", "2", "3"]

    node_labels = {
      "nodepool-type" = "system"
      "environment"   = var.environment
    }

    tags = local.tags
  }

  # Networking — Azure CNI
  network_profile {
    network_plugin    = "azure"
    network_policy    = "calico"
    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"
    service_cidr      = "172.16.0.0/16"
    dns_service_ip    = "172.16.0.10"
  }

  # Azure Monitor (Container Insights)
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  # Key Vault Secrets Provider
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  # Maintenance window
  maintenance_window {
    allowed {
      day   = "Sunday"
      hours = [2, 3, 4]
    }
  }

  tags = local.tags
}

# -----------------------------------------------------------------------------
# User Node Pool (Application Workloads)
# -----------------------------------------------------------------------------
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.aks_node_vm_size
  vnet_subnet_id        = azurerm_subnet.aks_user.id
  min_count             = var.aks_user_node_min
  max_count             = var.aks_user_node_max
  enable_auto_scaling   = true
  os_disk_size_gb       = 128
  max_pods              = 110
  mode                  = "User"
  zones                 = ["1", "2", "3"]

  node_labels = {
    "nodepool-type" = "user"
    "environment"   = var.environment
  }

  node_taints = []

  tags = local.tags
}

# -----------------------------------------------------------------------------
# Diagnostic Settings for AKS
# -----------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "${local.name_prefix}-aks-diag"
  target_resource_id         = azurerm_kubernetes_cluster.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "kube-apiserver"
  }

  enabled_log {
    category = "kube-audit"
  }

  enabled_log {
    category = "kube-audit-admin"
  }

  enabled_log {
    category = "kube-controller-manager"
  }

  enabled_log {
    category = "kube-scheduler"
  }

  enabled_log {
    category = "guard"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
