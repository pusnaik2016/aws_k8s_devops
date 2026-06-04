# =============================================================================
# AWS VPN — Cross-Cloud IPSec Tunnels
# =============================================================================
# Connects AWS VPC to Azure VNet and GCP VPC via IPSec/IKEv2
# BGP dynamic routing (ASN 65000) for automatic route propagation
# =============================================================================

# -----------------------------------------------------------------------------
# Virtual Private Gateway
# -----------------------------------------------------------------------------
resource "aws_vpn_gateway" "main" {
  vpc_id          = aws_vpc.main.id
  amazon_side_asn = 65000

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-vgw"
  })
}

# Enable route propagation to private subnets
resource "aws_vpn_gateway_route_propagation" "private_app" {
  count          = 2
  vpn_gateway_id = aws_vpn_gateway.main.id
  route_table_id = aws_route_table.private_app[count.index].id
}

resource "aws_vpn_gateway_route_propagation" "private_data" {
  count          = 2
  vpn_gateway_id = aws_vpn_gateway.main.id
  route_table_id = aws_route_table.private_data[count.index].id
}

# -----------------------------------------------------------------------------
# Customer Gateway — Azure VPN Peer
# -----------------------------------------------------------------------------
resource "aws_customer_gateway" "azure" {
  bgp_asn    = 65001
  ip_address = var.azure_vpn_gateway_ip
  type       = "ipsec.1"

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-cgw-azure"
  })
}

# -----------------------------------------------------------------------------
# Customer Gateway — GCP VPN Peer
# -----------------------------------------------------------------------------
resource "aws_customer_gateway" "gcp" {
  bgp_asn    = 65002
  ip_address = var.gcp_vpn_gateway_ip
  type       = "ipsec.1"

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-cgw-gcp"
  })
}

# -----------------------------------------------------------------------------
# VPN Connection — AWS ↔ Azure
# -----------------------------------------------------------------------------
resource "aws_vpn_connection" "azure" {
  vpn_gateway_id      = aws_vpn_gateway.main.id
  customer_gateway_id = aws_customer_gateway.azure.id
  type                = "ipsec.1"
  static_routes_only  = false # Use BGP

  tunnel1_ike_versions                 = ["ikev2"]
  tunnel1_phase1_encryption_algorithms = ["AES256-GCM-16"]
  tunnel1_phase1_integrity_algorithms  = ["SHA2-384"]
  tunnel1_phase1_dh_group_numbers      = [20]
  tunnel1_phase2_encryption_algorithms = ["AES256-GCM-16"]
  tunnel1_phase2_integrity_algorithms  = ["SHA2-384"]
  tunnel1_phase2_dh_group_numbers      = [20]
  tunnel1_preshared_key                = var.vpn_shared_secret_azure

  tunnel2_ike_versions                 = ["ikev2"]
  tunnel2_phase1_encryption_algorithms = ["AES256-GCM-16"]
  tunnel2_phase1_integrity_algorithms  = ["SHA2-384"]
  tunnel2_phase1_dh_group_numbers      = [20]
  tunnel2_phase2_encryption_algorithms = ["AES256-GCM-16"]
  tunnel2_phase2_integrity_algorithms  = ["SHA2-384"]
  tunnel2_phase2_dh_group_numbers      = [20]
  tunnel2_preshared_key                = var.vpn_shared_secret_azure

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-vpn-azure"
  })
}

# -----------------------------------------------------------------------------
# VPN Connection — AWS ↔ GCP
# -----------------------------------------------------------------------------
resource "aws_vpn_connection" "gcp" {
  vpn_gateway_id      = aws_vpn_gateway.main.id
  customer_gateway_id = aws_customer_gateway.gcp.id
  type                = "ipsec.1"
  static_routes_only  = false

  tunnel1_ike_versions                 = ["ikev2"]
  tunnel1_phase1_encryption_algorithms = ["AES256-GCM-16"]
  tunnel1_phase1_integrity_algorithms  = ["SHA2-384"]
  tunnel1_phase1_dh_group_numbers      = [20]
  tunnel1_phase2_encryption_algorithms = ["AES256-GCM-16"]
  tunnel1_phase2_integrity_algorithms  = ["SHA2-384"]
  tunnel1_phase2_dh_group_numbers      = [20]
  tunnel1_preshared_key                = var.vpn_shared_secret_gcp

  tunnel2_ike_versions                 = ["ikev2"]
  tunnel2_phase1_encryption_algorithms = ["AES256-GCM-16"]
  tunnel2_phase1_integrity_algorithms  = ["SHA2-384"]
  tunnel2_phase1_dh_group_numbers      = [20]
  tunnel2_phase2_encryption_algorithms = ["AES256-GCM-16"]
  tunnel2_phase2_integrity_algorithms  = ["SHA2-384"]
  tunnel2_phase2_dh_group_numbers      = [20]
  tunnel2_preshared_key                = var.vpn_shared_secret_gcp

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-vpn-gcp"
  })
}
