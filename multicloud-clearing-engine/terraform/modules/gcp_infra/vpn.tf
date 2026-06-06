# =============================================================================
# GCP HA VPN — Cross-Cloud Tunnels
# =============================================================================

resource "google_compute_ha_vpn_gateway" "main" {
  name    = "${local.name_prefix}-vpn-gw"
  region  = var.region
  network = google_compute_network.main.id
}

# --- AWS VPN Peer ---
resource "google_compute_external_vpn_gateway" "aws" {
  name            = "${local.name_prefix}-aws-peer"
  redundancy_type = "SINGLE_IP_INTERNALLY_REDUNDANT"

  interface {
    id         = 0
    ip_address = var.aws_vpn_gateway_ip
  }
}

resource "google_compute_vpn_tunnel" "aws_tunnel_0" {
  name                            = "${local.name_prefix}-aws-tunnel-0"
  region                          = var.region
  vpn_gateway                     = google_compute_ha_vpn_gateway.main.id
  vpn_gateway_interface           = 0
  peer_external_gateway           = google_compute_external_vpn_gateway.aws.id
  peer_external_gateway_interface = 0
  shared_secret                   = var.vpn_shared_secret_aws
  router                          = google_compute_router.main.id
  ike_version                     = 2
}

resource "google_compute_vpn_tunnel" "aws_tunnel_1" {
  name                            = "${local.name_prefix}-aws-tunnel-1"
  region                          = var.region
  vpn_gateway                     = google_compute_ha_vpn_gateway.main.id
  vpn_gateway_interface           = 1
  peer_external_gateway           = google_compute_external_vpn_gateway.aws.id
  peer_external_gateway_interface = 0
  shared_secret                   = var.vpn_shared_secret_aws
  router                          = google_compute_router.main.id
  ike_version                     = 2
}

# BGP sessions for AWS
resource "google_compute_router_interface" "aws_0" {
  name       = "${local.name_prefix}-aws-if-0"
  router     = google_compute_router.main.name
  region     = var.region
  ip_range   = "169.254.1.1/30"
  vpn_tunnel = google_compute_vpn_tunnel.aws_tunnel_0.name
}

resource "google_compute_router_peer" "aws_0" {
  name                      = "${local.name_prefix}-aws-bgp-0"
  router                    = google_compute_router.main.name
  region                    = var.region
  peer_ip_address           = "169.254.1.2"
  peer_asn                  = 65000
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.aws_0.name
}

resource "google_compute_router_interface" "aws_1" {
  name       = "${local.name_prefix}-aws-if-1"
  router     = google_compute_router.main.name
  region     = var.region
  ip_range   = "169.254.2.1/30"
  vpn_tunnel = google_compute_vpn_tunnel.aws_tunnel_1.name
}

resource "google_compute_router_peer" "aws_1" {
  name                      = "${local.name_prefix}-aws-bgp-1"
  router                    = google_compute_router.main.name
  region                    = var.region
  peer_ip_address           = "169.254.2.2"
  peer_asn                  = 65000
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.aws_1.name
}

# --- Azure VPN Peer ---
resource "google_compute_external_vpn_gateway" "azure" {
  name            = "${local.name_prefix}-azure-peer"
  redundancy_type = "SINGLE_IP_INTERNALLY_REDUNDANT"

  interface {
    id         = 0
    ip_address = var.azure_vpn_gateway_ip
  }
}

resource "google_compute_vpn_tunnel" "azure_tunnel_0" {
  name                            = "${local.name_prefix}-azure-tunnel-0"
  region                          = var.region
  vpn_gateway                     = google_compute_ha_vpn_gateway.main.id
  vpn_gateway_interface           = 0
  peer_external_gateway           = google_compute_external_vpn_gateway.azure.id
  peer_external_gateway_interface = 0
  shared_secret                   = var.vpn_shared_secret_azure
  router                          = google_compute_router.main.id
  ike_version                     = 2
}

resource "google_compute_vpn_tunnel" "azure_tunnel_1" {
  name                            = "${local.name_prefix}-azure-tunnel-1"
  region                          = var.region
  vpn_gateway                     = google_compute_ha_vpn_gateway.main.id
  vpn_gateway_interface           = 1
  peer_external_gateway           = google_compute_external_vpn_gateway.azure.id
  peer_external_gateway_interface = 0
  shared_secret                   = var.vpn_shared_secret_azure
  router                          = google_compute_router.main.id
  ike_version                     = 2
}

# BGP sessions for Azure
resource "google_compute_router_interface" "azure_0" {
  name       = "${local.name_prefix}-azure-if-0"
  router     = google_compute_router.main.name
  region     = var.region
  ip_range   = "169.254.3.1/30"
  vpn_tunnel = google_compute_vpn_tunnel.azure_tunnel_0.name
}

resource "google_compute_router_peer" "azure_0" {
  name                      = "${local.name_prefix}-azure-bgp-0"
  router                    = google_compute_router.main.name
  region                    = var.region
  peer_ip_address           = "169.254.3.2"
  peer_asn                  = 65001
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.azure_0.name
}

resource "google_compute_router_interface" "azure_1" {
  name       = "${local.name_prefix}-azure-if-1"
  router     = google_compute_router.main.name
  region     = var.region
  ip_range   = "169.254.4.1/30"
  vpn_tunnel = google_compute_vpn_tunnel.azure_tunnel_1.name
}

resource "google_compute_router_peer" "azure_1" {
  name                      = "${local.name_prefix}-azure-bgp-1"
  router                    = google_compute_router.main.name
  region                    = var.region
  peer_ip_address           = "169.254.4.2"
  peer_asn                  = 65001
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.azure_1.name
}
