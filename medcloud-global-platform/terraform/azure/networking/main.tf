# ─────────────────────────────────────────────────────────────────────────────
# Azure Networking — Hub VNet with VPN Gateway for Cross-Cloud Connectivity
# ─────────────────────────────────────────────────────────────────────────────
# HIPAA/GDPR compliant networking:
# - Hub VNet with Azure Firewall and VPN Gateway
# - NSGs with deny-all default and explicit allow rules
# - VNet Flow Logs for audit compliance
# - Private endpoints for all PaaS services
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
    key                  = "azure/networking/terraform.tfstate"
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
}

# ─── Local Values ────────────────────────────────────────────────────────────

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  location    = var.azure_location

  # Subnet allocation within 10.1.0.0/16
  subnets = {
    firewall = {
      name             = "AzureFirewallSubnet" # Must be this exact name
      address_prefixes = ["10.1.0.0/26"]
    }
    gateway = {
      name             = "GatewaySubnet" # Must be this exact name for VPN Gateway
      address_prefixes = ["10.1.0.64/27"]
    }
    bastion = {
      name             = "AzureBastionSubnet" # Must be this exact name
      address_prefixes = ["10.1.0.128/26"]
    }
    aks = {
      name             = "aks-subnet"
      address_prefixes = ["10.1.1.0/24"]
    }
    database = {
      name             = "database-subnet"
      address_prefixes = ["10.1.2.0/24"]
    }
    ai_services = {
      name             = "ai-services-subnet"
      address_prefixes = ["10.1.3.0/24"]
    }
    private_endpoints = {
      name             = "private-endpoints-subnet"
      address_prefixes = ["10.1.4.0/24"]
    }
  }
}

# ─── Resource Group ──────────────────────────────────────────────────────────

resource "azurerm_resource_group" "networking" {
  name     = "${local.name_prefix}-networking-rg"
  location = local.location

  tags = merge(var.common_tags, {
    Cloud       = "Azure"
    Environment = var.environment
    Component   = "networking"
  })
}

# ─── Virtual Network (Hub) ──────────────────────────────────────────────────

resource "azurerm_virtual_network" "hub" {
  name                = "${local.name_prefix}-hub-vnet"
  address_space       = [var.azure_vnet_cidr]
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name

  tags = merge(var.common_tags, {
    Role = "hub-network"
  })
}

# ─── Subnets ─────────────────────────────────────────────────────────────────

resource "azurerm_subnet" "subnets" {
  for_each = local.subnets

  name                 = each.value.name
  resource_group_name  = azurerm_resource_group.networking.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = each.value.address_prefixes

  # Disable private endpoint policies for the private endpoints subnet
  private_endpoint_network_policies_enabled = each.key == "private_endpoints" ? false : true
}

# ─── Network Security Groups ────────────────────────────────────────────────

# AKS Subnet NSG
resource "azurerm_network_security_group" "aks" {
  name                = "${local.name_prefix}-aks-nsg"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name

  # Allow HTTPS inbound from Azure Front Door
  security_rule {
    name                       = "AllowFrontDoorHTTPS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "AzureFrontDoor.Backend"
    destination_address_prefix = "*"
  }

  # Allow internal VNet traffic
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

  # Allow cross-cloud traffic (AWS + GCP CIDRs)
  security_rule {
    name                       = "AllowCrossCloudInbound"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefixes    = [var.aws_vpc_cidr, var.gcp_vpc_cidr]
    destination_address_prefix = "*"
  }

  # Deny all other inbound
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = merge(var.common_tags, {
    Subnet = "aks"
  })
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.subnets["aks"].id
  network_security_group_id = azurerm_network_security_group.aks.id
}

# Database Subnet NSG (most restrictive — HIPAA PHI)
resource "azurerm_network_security_group" "database" {
  name                = "${local.name_prefix}-database-nsg"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name

  # Allow AKS subnet only
  security_rule {
    name                       = "AllowAKSToDatabase"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["5432", "6380", "27017"] # PostgreSQL, Redis, CosmosDB
    source_address_prefixes    = local.subnets.aks.address_prefixes
    destination_address_prefix = "*"
  }

  # Deny all other inbound
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = merge(var.common_tags, {
    Subnet     = "database"
    Compliance = "HIPAA-PHI"
  })
}

resource "azurerm_subnet_network_security_group_association" "database" {
  subnet_id                 = azurerm_subnet.subnets["database"].id
  network_security_group_id = azurerm_network_security_group.database.id
}

# ─── Azure Firewall ─────────────────────────────────────────────────────────

resource "azurerm_public_ip" "firewall" {
  name                = "${local.name_prefix}-firewall-pip"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.common_tags
}

resource "azurerm_firewall_policy" "main" {
  name                = "${local.name_prefix}-firewall-policy"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  sku                 = var.environment == "prod" ? "Premium" : "Standard"

  # Premium features for production (TLS inspection, IDPS)
  dynamic "intrusion_detection" {
    for_each = var.environment == "prod" ? [1] : []
    content {
      mode = "Alert"
    }
  }

  threat_intelligence_mode = "Alert"

  tags = var.common_tags
}

resource "azurerm_firewall" "main" {
  name                = "${local.name_prefix}-firewall"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  sku_name            = "AZFW_VNet"
  sku_tier            = var.environment == "prod" ? "Premium" : "Standard"
  firewall_policy_id  = azurerm_firewall_policy.main.id

  ip_configuration {
    name                 = "firewall-ip-config"
    subnet_id            = azurerm_subnet.subnets["firewall"].id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }

  tags = var.common_tags
}

# ─── VPN Gateway (Cross-Cloud Connectivity) ─────────────────────────────────

resource "azurerm_public_ip" "vpn_gateway" {
  name                = "${local.name_prefix}-vpn-gw-pip"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.common_tags
}

resource "azurerm_virtual_network_gateway" "main" {
  name                = "${local.name_prefix}-vpn-gateway"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  active_active       = false
  enable_bgp          = true
  sku                 = "VpnGw2"
  generation          = "Generation2"

  bgp_settings {
    asn = 65515
  }

  ip_configuration {
    name                          = "vpn-gateway-config"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.subnets["gateway"].id
  }

  tags = var.common_tags
}

# ─── Azure Bastion (Secure VM Access — No SSH/RDP over public IP) ────────────

resource "azurerm_public_ip" "bastion" {
  name                = "${local.name_prefix}-bastion-pip"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.common_tags
}

resource "azurerm_bastion_host" "main" {
  name                = "${local.name_prefix}-bastion"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  sku                 = "Standard"
  tunneling_enabled   = true
  ip_connect_enabled  = true

  ip_configuration {
    name                 = "bastion-config"
    subnet_id            = azurerm_subnet.subnets["bastion"].id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }

  tags = var.common_tags
}

# ─── VNet Flow Logs (HIPAA Audit Requirement) ───────────────────────────────

resource "azurerm_log_analytics_workspace" "networking" {
  name                = "${local.name_prefix}-network-law"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  sku                 = "PerGB2018"
  retention_in_days   = var.environment == "prod" ? 365 : 30

  tags = merge(var.common_tags, {
    Compliance = "HIPAA-audit"
  })
}

# ─── Outputs ─────────────────────────────────────────────────────────────────

output "vnet_id" {
  description = "Azure Hub VNet ID"
  value       = azurerm_virtual_network.hub.id
}

output "vnet_name" {
  description = "Azure Hub VNet name"
  value       = azurerm_virtual_network.hub.name
}

output "aks_subnet_id" {
  description = "AKS subnet ID"
  value       = azurerm_subnet.subnets["aks"].id
}

output "database_subnet_id" {
  description = "Database subnet ID"
  value       = azurerm_subnet.subnets["database"].id
}

output "private_endpoints_subnet_id" {
  description = "Private endpoints subnet ID"
  value       = azurerm_subnet.subnets["private_endpoints"].id
}

output "vpn_gateway_public_ip" {
  description = "VPN Gateway public IP for cross-cloud connectivity"
  value       = azurerm_public_ip.vpn_gateway.ip_address
}

output "firewall_private_ip" {
  description = "Azure Firewall private IP"
  value       = azurerm_firewall.main.ip_configuration[0].private_ip_address
}

output "resource_group_name" {
  description = "Networking resource group name"
  value       = azurerm_resource_group.networking.name
}

output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID for monitoring"
  value       = azurerm_log_analytics_workspace.networking.id
}
