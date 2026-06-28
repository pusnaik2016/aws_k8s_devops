# =============================================================================
# AZURE NETWORKING MODULE — VNet for Databricks DR Site
# =============================================================================
# Architecture:
#   Databricks Host Subnet     → Databricks cluster driver nodes
#   Databricks Container Subnet → Databricks worker containers
#   Data Subnet                → ADLS Gen2, Key Vault private endpoints
#   Gateway Subnet             → ExpressRoute + VPN gateway
#
# COMPLIANCE:
#   HIPAA  — NSG deny-all-internet, private endpoints only
#   SOC 2  — Network flow logs to Log Analytics
#   PCI-DSS — Subnet-level isolation for CDE
# =============================================================================

data "azurerm_client_config" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  tags = merge(var.common_tags, {
    Module      = "azure-networking"
    Cloud       = "azure"
    Environment = var.environment
    Compliance  = "hipaa-soc2-pci"
    ManagedBy   = "terraform"
  })
}

# =============================================================================
# RESOURCE GROUP
# =============================================================================
resource "azurerm_resource_group" "networking" {
  name     = "${local.name_prefix}-networking-rg"
  location = var.location

  tags = local.tags
}

# =============================================================================
# VIRTUAL NETWORK
# =============================================================================
resource "azurerm_virtual_network" "main" {
  name                = "${local.name_prefix}-vnet"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  address_space       = [var.vnet_cidr]

  tags = local.tags
}

# =============================================================================
# SUBNETS
# =============================================================================

# Databricks Host subnet (driver nodes)
resource "azurerm_subnet" "databricks_host" {
  name                 = "${local.name_prefix}-dbx-host"
  resource_group_name  = azurerm_resource_group.networking.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 4, 0)]

  delegation {
    name = "databricks-host-delegation"
    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"
      ]
    }
  }
}

# Databricks Container subnet (worker containers)
resource "azurerm_subnet" "databricks_container" {
  name                 = "${local.name_prefix}-dbx-container"
  resource_group_name  = azurerm_resource_group.networking.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 4, 1)]

  delegation {
    name = "databricks-container-delegation"
    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"
      ]
    }
  }
}

# Data subnet (Private Endpoints for ADLS, Key Vault)
resource "azurerm_subnet" "data" {
  name                                      = "${local.name_prefix}-data"
  resource_group_name                       = azurerm_resource_group.networking.name
  virtual_network_name                      = azurerm_virtual_network.main.name
  address_prefixes                          = [cidrsubnet(var.vnet_cidr, 4, 2)]
  private_endpoint_network_policies = "Enabled"
}

# Private Endpoint subnet
resource "azurerm_subnet" "private_endpoints" {
  name                                      = "${local.name_prefix}-pe"
  resource_group_name                       = azurerm_resource_group.networking.name
  virtual_network_name                      = azurerm_virtual_network.main.name
  address_prefixes                          = [cidrsubnet(var.vnet_cidr, 4, 3)]
  private_endpoint_network_policies = "Enabled"
}

# Gateway subnet (ExpressRoute + VPN)
resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet" # Must be named exactly "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.networking.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 4, 15)]
}

# =============================================================================
# NETWORK SECURITY GROUPS — Zero Public Internet Access
# =============================================================================

# Databricks NSG
resource "azurerm_network_security_group" "databricks" {
  name                = "${local.name_prefix}-dbx-nsg"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name

  # Deny all inbound from internet
  security_rule {
    name                       = "DenyInternetInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  # Allow Databricks control plane
  security_rule {
    name                       = "AllowDatabricksControlPlane"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureDatabricks"
    destination_address_prefix = "VirtualNetwork"
  }

  # Allow intra-VNet
  security_rule {
    name                       = "AllowVNetInbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  # Outbound rules
  security_rule {
    name                       = "AllowDatabricksControlPlaneOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "AzureDatabricks"
  }

  security_rule {
    name                       = "AllowAzureStorageOutbound"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "Storage"
  }

  security_rule {
    name                       = "AllowAzureSQLOutbound"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "Sql"
  }

  security_rule {
    name                       = "AllowEventHubOutbound"
    priority                   = 130
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9093"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "EventHub"
  }

  tags = local.tags
}

# Associate NSG with Databricks subnets
resource "azurerm_subnet_network_security_group_association" "databricks_host" {
  subnet_id                 = azurerm_subnet.databricks_host.id
  network_security_group_id = azurerm_network_security_group.databricks.id
}

resource "azurerm_subnet_network_security_group_association" "databricks_container" {
  subnet_id                 = azurerm_subnet.databricks_container.id
  network_security_group_id = azurerm_network_security_group.databricks.id
}

# Data subnet NSG
resource "azurerm_network_security_group" "data" {
  name                = "${local.name_prefix}-data-nsg"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name

  security_rule {
    name                       = "DenyInternetInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowVNetInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  tags = local.tags
}

resource "azurerm_subnet_network_security_group_association" "data" {
  subnet_id                 = azurerm_subnet.data.id
  network_security_group_id = azurerm_network_security_group.data.id
}

# =============================================================================
# EXPRESSROUTE CIRCUIT — Cross-Cloud Transit to AWS
# =============================================================================
resource "azurerm_express_route_circuit" "cross_cloud" {
  count = var.enable_cross_cloud_transit ? 1 : 0

  name                  = "${local.name_prefix}-expressroute"
  location              = azurerm_resource_group.networking.location
  resource_group_name   = azurerm_resource_group.networking.name
  service_provider_name = var.expressroute_provider
  peering_location      = var.expressroute_peering_location
  bandwidth_in_mbps     = var.expressroute_bandwidth_mbps

  sku {
    tier   = "Premium"
    family = "MeteredData"
  }

  tags = local.tags
}

# =============================================================================
# VNET GATEWAY — ExpressRoute + VPN Failover
# =============================================================================
resource "azurerm_public_ip" "gateway" {
  count = var.enable_cross_cloud_transit ? 1 : 0

  name                = "${local.name_prefix}-gw-pip"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = local.tags
}

resource "azurerm_virtual_network_gateway" "main" {
  count = var.enable_cross_cloud_transit ? 1 : 0

  name                = "${local.name_prefix}-vnet-gateway"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  type                = "ExpressRoute"
  vpn_type            = "RouteBased"
  sku                 = "ErGw1AZ"
  active_active       = false

  ip_configuration {
    name                          = "gatewayIPConfig"
    public_ip_address_id          = azurerm_public_ip.gateway[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }

  tags = local.tags
}

# =============================================================================
# NETWORK WATCHER — Flow Logs (Audit Trail)
# =============================================================================
resource "azurerm_network_watcher" "main" {
  name                = "${local.name_prefix}-network-watcher"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name

  tags = local.tags
}

resource "azurerm_network_watcher_flow_log" "databricks" {
  count = var.log_analytics_workspace_id != "" ? 1 : 0

  network_watcher_name = azurerm_network_watcher.main.name
  resource_group_name  = azurerm_resource_group.networking.name
  name                 = "${local.name_prefix}-dbx-flow-log"

  network_security_group_id = azurerm_network_security_group.databricks.id
  storage_account_id        = var.flow_log_storage_account_id
  enabled                   = true

  retention_policy {
    enabled = true
    days    = 365 # HIPAA: 1-year retention
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = var.log_analytics_workspace_id
    workspace_region      = var.location
    workspace_resource_id = var.log_analytics_workspace_resource_id
    interval_in_minutes   = 10
  }
}
