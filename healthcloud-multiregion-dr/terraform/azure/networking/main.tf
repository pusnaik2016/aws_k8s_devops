# ============================================================================
# Azure Networking — VNet, Subnets, NAT Gateway, VPN Gateway (DR)
# ============================================================================
# DR Region: eastus | Cross-cloud VPN to AWS us-east-1
# ============================================================================

terraform {
  required_version = ">= 1.5"
}

resource "azurerm_resource_group" "networking" {
  name     = "${var.project}-${var.environment}-networking-rg"
  location = var.azure_region

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-networking-rg"
  })
}

# ──────────────────────────────────────────────────────────────────────────────
# Virtual Network
# ──────────────────────────────────────────────────────────────────────────────

resource "azurerm_virtual_network" "main" {
  name                = "${var.project}-${var.environment}-vnet"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  address_space       = [var.vnet_cidr]

  tags = merge(var.common_tags, {
    Name               = "${var.project}-${var.environment}-vnet"
    DataClassification = "confidential"
  })
}

resource "azurerm_subnet" "aks" {
  name                 = "${var.project}-${var.environment}-aks-subnet"
  resource_group_name  = azurerm_resource_group.networking.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 4, 0)]
}

resource "azurerm_subnet" "database" {
  name                 = "${var.project}-${var.environment}-database-subnet"
  resource_group_name  = azurerm_resource_group.networking.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 4, 1)]

  delegation {
    name = "postgresql-delegation"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"  # Must be named exactly this
  resource_group_name  = azurerm_resource_group.networking.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 4, 2)]
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "${var.project}-${var.environment}-pe-subnet"
  resource_group_name  = azurerm_resource_group.networking.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 4, 3)]
}

# ──────────────────────────────────────────────────────────────────────────────
# NSG — Default Deny + Allow Rules
# ──────────────────────────────────────────────────────────────────────────────

resource "azurerm_network_security_group" "aks" {
  name                = "${var.project}-${var.environment}-aks-nsg"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name

  security_rule {
    name                       = "allow-https-inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.aws_vpc_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "deny-all-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-aks-nsg"
  })
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

# ──────────────────────────────────────────────────────────────────────────────
# NAT Gateway
# ──────────────────────────────────────────────────────────────────────────────

resource "azurerm_public_ip" "nat" {
  name                = "${var.project}-${var.environment}-nat-pip"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.common_tags
}

resource "azurerm_nat_gateway" "main" {
  name                    = "${var.project}-${var.environment}-nat-gw"
  location                = azurerm_resource_group.networking.location
  resource_group_name     = azurerm_resource_group.networking.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10

  tags = var.common_tags
}

resource "azurerm_nat_gateway_public_ip_association" "main" {
  nat_gateway_id       = azurerm_nat_gateway.main.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "aks" {
  subnet_id      = azurerm_subnet.aks.id
  nat_gateway_id = azurerm_nat_gateway.main.id
}

# ──────────────────────────────────────────────────────────────────────────────
# VPN Gateway — Cross-Cloud Connectivity to AWS
# ──────────────────────────────────────────────────────────────────────────────

resource "azurerm_public_ip" "vpn" {
  name                = "${var.project}-${var.environment}-vpn-pip"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.common_tags
}

resource "azurerm_virtual_network_gateway" "vpn" {
  name                = "${var.project}-${var.environment}-vpn-gw"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw1"
  active_active       = false
  enable_bgp          = false

  ip_configuration {
    name                          = "vpn-ip-config"
    public_ip_address_id          = azurerm_public_ip.vpn.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-vpn-gw"
  })
}

resource "azurerm_local_network_gateway" "aws" {
  name                = "${var.project}-${var.environment}-aws-lng"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  gateway_address     = var.aws_vpn_gateway_ip
  address_space       = [var.aws_vpc_cidr]

  tags = var.common_tags
}

resource "azurerm_virtual_network_gateway_connection" "aws" {
  name                       = "${var.project}-${var.environment}-aws-vpn-conn"
  location                   = azurerm_resource_group.networking.location
  resource_group_name        = azurerm_resource_group.networking.name
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vpn.id
  local_network_gateway_id   = azurerm_local_network_gateway.aws.id
  shared_key                 = var.vpn_shared_key

  ipsec_policy {
    dh_group         = "DHGroup14"
    ike_encryption   = "AES256"
    ike_integrity    = "SHA256"
    ipsec_encryption = "AES256"
    ipsec_integrity  = "SHA256"
    pfs_group        = "PFS14"
    sa_datasize      = 102400000
    sa_lifetime      = 27000
  }

  tags = var.common_tags
}

# ──────────────────────────────────────────────────────────────────────────────
# DNS Zone for DR
# ──────────────────────────────────────────────────────────────────────────────

resource "azurerm_private_dns_zone" "internal" {
  name                = "${var.project}-${var.environment}.internal"
  resource_group_name = azurerm_resource_group.networking.name

  tags = var.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "main" {
  name                  = "${var.project}-${var.environment}-dns-link"
  resource_group_name   = azurerm_resource_group.networking.name
  private_dns_zone_name = azurerm_private_dns_zone.internal.name
  virtual_network_id    = azurerm_virtual_network.main.id

  tags = var.common_tags
}
