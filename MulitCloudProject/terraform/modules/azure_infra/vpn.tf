# =============================================================================
# AZURE VPN Gateway — Cross-Cloud Connectivity
# =============================================================================

resource "azurerm_public_ip" "vpn_gw" {
  name                = "${local.name_prefix}-vpn-gw-ip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]

  tags = local.tags
}

resource "azurerm_public_ip" "vpn_gw_secondary" {
  name                = "${local.name_prefix}-vpn-gw-ip-2"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]

  tags = local.tags
}

resource "azurerm_virtual_network_gateway" "main" {
  name                = "${local.name_prefix}-vpn-gw"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  type     = "Vpn"
  vpn_type = "RouteBased"
  sku      = "VpnGw2"

  active_active = true
  enable_bgp    = true

  bgp_settings {
    asn = 65001
  }

  ip_configuration {
    name                          = "primary"
    public_ip_address_id          = azurerm_public_ip.vpn_gw.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }

  ip_configuration {
    name                          = "secondary"
    public_ip_address_id          = azurerm_public_ip.vpn_gw_secondary.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }

  tags = local.tags
}

# --- AWS Local Network Gateway ---
resource "azurerm_local_network_gateway" "aws" {
  name                = "${local.name_prefix}-lng-aws"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  gateway_address     = var.aws_vpn_gateway_ip
  address_space       = [var.aws_vpc_cidr]

  bgp_settings {
    asn                 = 65000
    bgp_peering_address = var.aws_vpn_gateway_ip
  }

  tags = local.tags
}

resource "azurerm_virtual_network_gateway_connection" "aws" {
  name                       = "${local.name_prefix}-conn-aws"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.main.id
  local_network_gateway_id   = azurerm_local_network_gateway.aws.id
  shared_key                 = var.vpn_shared_secret_aws
  enable_bgp                 = true

  ipsec_policy {
    ike_encryption   = "AES256"
    ike_integrity    = "SHA384"
    dh_group         = "DHGroup20"
    ipsec_encryption = "GCMAES256"
    ipsec_integrity  = "GCMAES256"
    pfs_group        = "PFS2048"
    sa_lifetime      = 3600
  }

  tags = local.tags
}

# --- GCP Local Network Gateway ---
resource "azurerm_local_network_gateway" "gcp" {
  name                = "${local.name_prefix}-lng-gcp"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  gateway_address     = var.gcp_vpn_gateway_ip
  address_space       = [var.gcp_vpc_cidr]

  bgp_settings {
    asn                 = 65002
    bgp_peering_address = var.gcp_vpn_gateway_ip
  }

  tags = local.tags
}

resource "azurerm_virtual_network_gateway_connection" "gcp" {
  name                       = "${local.name_prefix}-conn-gcp"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.main.id
  local_network_gateway_id   = azurerm_local_network_gateway.gcp.id
  shared_key                 = var.vpn_shared_secret_gcp
  enable_bgp                 = true

  ipsec_policy {
    ike_encryption   = "AES256"
    ike_integrity    = "SHA384"
    dh_group         = "DHGroup20"
    ipsec_encryption = "GCMAES256"
    ipsec_integrity  = "GCMAES256"
    pfs_group        = "PFS2048"
    sa_lifetime      = 3600
  }

  tags = local.tags
}
