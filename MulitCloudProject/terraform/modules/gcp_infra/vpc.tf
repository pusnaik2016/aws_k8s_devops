# =============================================================================
# GCP VPC — Custom Subnet Mode
# =============================================================================

resource "google_compute_network" "main" {
  name                    = "${local.name_prefix}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"

  depends_on = [google_project_service.apis]
}

# GKE Nodes Subnet
resource "google_compute_subnetwork" "gke_nodes" {
  name          = "${local.name_prefix}-gke-nodes"
  ip_cidr_range = cidrsubnet(var.vpc_cidr, 4, 0) # /20
  region        = var.region
  network       = google_compute_network.main.id

  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }

  secondary_ip_range {
    range_name    = "gke-pods"
    ip_cidr_range = "10.3.0.0/16"
  }

  secondary_ip_range {
    range_name    = "gke-services"
    ip_cidr_range = "10.4.0.0/20"
  }
}

# Data Subnet (AlloyDB, Private Services)
resource "google_compute_subnetwork" "data" {
  name          = "${local.name_prefix}-data"
  ip_cidr_range = cidrsubnet(var.vpc_cidr, 4, 1) # /20
  region        = var.region
  network       = google_compute_network.main.id

  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Private Services Access (for AlloyDB)
resource "google_compute_global_address" "private_services" {
  name          = "${local.name_prefix}-private-svc-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 20
  network       = google_compute_network.main.id
}

resource "google_service_networking_connection" "private_services" {
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services.name]

  depends_on = [google_project_service.apis]
}

# Cloud Router (for BGP with AWS/Azure VPN + Cloud NAT)
resource "google_compute_router" "main" {
  name    = "${local.name_prefix}-router"
  region  = var.region
  network = google_compute_network.main.id

  bgp {
    asn               = 65002
    advertise_mode    = "CUSTOM"

    advertised_ip_ranges {
      range       = var.vpc_cidr
      description = "GCP VPC primary range"
    }
  }
}

# Cloud NAT
resource "google_compute_router_nat" "main" {
  name                               = "${local.name_prefix}-nat"
  router                             = google_compute_router.main.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Firewall Rules
resource "google_compute_firewall" "deny_all_ingress" {
  name    = "${local.name_prefix}-deny-all-ingress"
  network = google_compute_network.main.id

  deny {
    protocol = "all"
  }

  direction     = "INGRESS"
  priority      = 65534
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_internal" {
  name    = "${local.name_prefix}-allow-internal"
  network = google_compute_network.main.id

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "icmp"
  }

  direction     = "INGRESS"
  priority      = 1000
  source_ranges = [var.vpc_cidr, "10.3.0.0/16", "10.4.0.0/20"]
}

resource "google_compute_firewall" "allow_vpn" {
  name    = "${local.name_prefix}-allow-vpn-traffic"
  network = google_compute_network.main.id

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "icmp"
  }

  direction     = "INGRESS"
  priority      = 900
  source_ranges = [var.aws_vpc_cidr, var.azure_vnet_cidr]
}
