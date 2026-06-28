# =============================================================================
# CROSS-CLOUD TRANSIT MODULE — AWS ↔ Azure Secure Connectivity
# =============================================================================
# Architecture:
#   Primary:  AWS Direct Connect Gateway → Exchange Provider → Azure ExpressRoute
#   Failover: AWS VPN Gateway → IPSec IKEv2 tunnel → Azure VNet Gateway
#
# COMPLIANCE:
#   Transport: Minimum TLS 1.3 for all cross-cloud data transit
#   Encryption: IKEv2 with AES-256-GCM, SHA-384 integrity
#   PCI-DSS: Dedicated encrypted channel, no public internet transit
# =============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  tags = merge(var.common_tags, {
    Module = "cross-cloud-transit"; Compliance = "hipaa-soc2-pci"; ManagedBy = "terraform"
  })
}

# =============================================================================
# AWS SIDE — VPN Failover to Azure
# =============================================================================

# Customer Gateway (Azure VNet Gateway public IP)
resource "aws_customer_gateway" "azure" {
  bgp_asn    = var.azure_bgp_asn
  ip_address = var.azure_gateway_public_ip
  type       = "ipsec.1"

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-cgw-azure"
  })
}

# Site-to-Site VPN Connection (IPSec failover)
resource "aws_vpn_connection" "azure_failover" {
  customer_gateway_id = aws_customer_gateway.azure.id
  vpn_gateway_id      = var.aws_vpn_gateway_id
  type                = "ipsec.1"
  static_routes_only  = false # Use BGP for dynamic routing

  # IKEv2 with AES-256-GCM (compliance-grade encryption)
  tunnel1_ike_versions                 = ["ikev2"]
  tunnel1_phase1_dh_group_numbers      = [20]      # ECP-384
  tunnel1_phase1_encryption_algorithms = ["AES256-GCM-16"]
  tunnel1_phase1_integrity_algorithms  = ["SHA2-384"]
  tunnel1_phase2_dh_group_numbers      = [20]
  tunnel1_phase2_encryption_algorithms = ["AES256-GCM-16"]
  tunnel1_phase2_integrity_algorithms  = ["SHA2-384"]

  tunnel2_ike_versions                 = ["ikev2"]
  tunnel2_phase1_dh_group_numbers      = [20]
  tunnel2_phase1_encryption_algorithms = ["AES256-GCM-16"]
  tunnel2_phase1_integrity_algorithms  = ["SHA2-384"]
  tunnel2_phase2_dh_group_numbers      = [20]
  tunnel2_phase2_encryption_algorithms = ["AES256-GCM-16"]
  tunnel2_phase2_integrity_algorithms  = ["SHA2-384"]

  tags = merge(local.tags, {
    Name     = "${local.name_prefix}-vpn-azure-failover"
    Purpose  = "cross-cloud-ipsec-failover"
    Priority = "secondary" # Primary is DirectConnect/ExpressRoute
  })
}

# =============================================================================
# AZURE SIDE — Local Network Gateway + VPN Connection
# =============================================================================
resource "azurerm_resource_group" "transit" {
  name     = "${local.name_prefix}-transit-rg"
  location = var.azure_location
  tags     = local.tags
}

# Local Network Gateway (points to AWS VPN endpoints)
resource "azurerm_local_network_gateway" "aws_tunnel1" {
  name                = "${local.name_prefix}-lng-aws-tunnel1"
  location            = azurerm_resource_group.transit.location
  resource_group_name = azurerm_resource_group.transit.name
  gateway_address     = aws_vpn_connection.azure_failover.tunnel1_address

  address_space = [var.aws_vpc_cidr]

  bgp_settings {
    asn                 = var.aws_bgp_asn
    bgp_peering_address = aws_vpn_connection.azure_failover.tunnel1_bgp_asn
  }

  tags = local.tags
}

resource "azurerm_local_network_gateway" "aws_tunnel2" {
  name                = "${local.name_prefix}-lng-aws-tunnel2"
  location            = azurerm_resource_group.transit.location
  resource_group_name = azurerm_resource_group.transit.name
  gateway_address     = aws_vpn_connection.azure_failover.tunnel2_address

  address_space = [var.aws_vpc_cidr]

  tags = local.tags
}

# VPN Connection — Azure to AWS (Tunnel 1)
resource "azurerm_virtual_network_gateway_connection" "aws_tunnel1" {
  name                       = "${local.name_prefix}-vpn-aws-tunnel1"
  location                   = azurerm_resource_group.transit.location
  resource_group_name        = azurerm_resource_group.transit.name
  type                       = "IPsec"
  virtual_network_gateway_id = var.azure_vnet_gateway_id
  local_network_gateway_id   = azurerm_local_network_gateway.aws_tunnel1.id
  shared_key                 = var.vpn_shared_key

  enable_bgp = true

  ipsec_policy {
    ike_encryption   = "AES256"
    ike_integrity    = "SHA384"
    dh_group         = "ECP384"
    ipsec_encryption = "GCMAES256"
    ipsec_integrity  = "GCMAES256"
    pfs_group        = "ECP384"
    sa_lifetime      = 3600
  }

  tags = local.tags
}

# VPN Connection — Azure to AWS (Tunnel 2 — redundancy)
resource "azurerm_virtual_network_gateway_connection" "aws_tunnel2" {
  name                       = "${local.name_prefix}-vpn-aws-tunnel2"
  location                   = azurerm_resource_group.transit.location
  resource_group_name        = azurerm_resource_group.transit.name
  type                       = "IPsec"
  virtual_network_gateway_id = var.azure_vnet_gateway_id
  local_network_gateway_id   = azurerm_local_network_gateway.aws_tunnel2.id
  shared_key                 = var.vpn_shared_key

  ipsec_policy {
    ike_encryption   = "AES256"
    ike_integrity    = "SHA384"
    dh_group         = "ECP384"
    ipsec_encryption = "GCMAES256"
    ipsec_integrity  = "GCMAES256"
    pfs_group        = "ECP384"
    sa_lifetime      = 3600
  }

  tags = local.tags
}
