# ─────────────────────────────────────────────────────────────────────────────
# GCP Networking — Global VPC with Regional Subnets & Cloud Router
# ─────────────────────────────────────────────────────────────────────────────
# HIPAA compliant networking:
# - Private Google Access enabled (no internet for GCP API calls)
# - VPC Flow Logs for audit compliance
# - Cloud NAT for controlled outbound
# - Cloud Router with HA VPN for cross-cloud connectivity
# - Firewall rules with deny-all default
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.20"
    }
  }

  backend "gcs" {
    bucket = "medcloud-terraform-state-gcp"
    prefix = "gcp/networking"
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# ─── Local Values ────────────────────────────────────────────────────────────

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # Subnet allocation within 10.2.0.0/16
  subnets = {
    gke = {
      name          = "${local.name_prefix}-gke-subnet"
      ip_cidr_range = "10.2.1.0/24"
      region        = var.gcp_region
      description   = "GKE cluster nodes"
      # GKE secondary ranges for pods and services
      pod_cidr     = "10.100.0.0/16"
      service_cidr = "10.101.0.0/20"
    }
    database = {
      name          = "${local.name_prefix}-database-subnet"
      ip_cidr_range = "10.2.2.0/24"
      region        = var.gcp_region
      description   = "Cloud SQL, Bigtable"
    }
    analytics = {
      name          = "${local.name_prefix}-analytics-subnet"
      ip_cidr_range = "10.2.3.0/24"
      region        = var.gcp_region
      description   = "BigQuery, Dataflow workers"
    }
    ml_platform = {
      name          = "${local.name_prefix}-ml-subnet"
      ip_cidr_range = "10.2.4.0/24"
      region        = var.gcp_region
      description   = "Vertex AI training and serving"
    }
  }
}

# ─── VPC Network (Global) ───────────────────────────────────────────────────

resource "google_compute_network" "main" {
  name                            = "${local.name_prefix}-vpc"
  auto_create_subnetworks         = false # Custom mode VPC
  routing_mode                    = "GLOBAL"
  delete_default_routes_on_create = false
  description                     = "MedCloud Global VPC - HIPAA compliant"
}

# ─── Subnets (Regional) ─────────────────────────────────────────────────────

# GKE subnet with secondary ranges for pods and services
resource "google_compute_subnetwork" "gke" {
  name          = local.subnets.gke.name
  ip_cidr_range = local.subnets.gke.ip_cidr_range
  region        = local.subnets.gke.region
  network       = google_compute_network.main.id
  description   = local.subnets.gke.description

  private_ip_google_access = true # HIPAA: Access Google APIs without internet

  # GKE Pod and Service secondary ranges
  secondary_ip_range {
    range_name    = "${local.name_prefix}-gke-pods"
    ip_cidr_range = local.subnets.gke.pod_cidr
  }

  secondary_ip_range {
    range_name    = "${local.name_prefix}-gke-services"
    ip_cidr_range = local.subnets.gke.service_cidr
  }

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
    filter_expr          = "true"
  }
}

# Database subnet
resource "google_compute_subnetwork" "database" {
  name          = local.subnets.database.name
  ip_cidr_range = local.subnets.database.ip_cidr_range
  region        = local.subnets.database.region
  network       = google_compute_network.main.id
  description   = local.subnets.database.description

  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 1.0 # Full sampling for database traffic (HIPAA audit)
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Analytics subnet
resource "google_compute_subnetwork" "analytics" {
  name          = local.subnets.analytics.name
  ip_cidr_range = local.subnets.analytics.ip_cidr_range
  region        = local.subnets.analytics.region
  network       = google_compute_network.main.id
  description   = local.subnets.analytics.description

  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# ML Platform subnet
resource "google_compute_subnetwork" "ml_platform" {
  name          = local.subnets.ml_platform.name
  ip_cidr_range = local.subnets.ml_platform.ip_cidr_range
  region        = local.subnets.ml_platform.region
  network       = google_compute_network.main.id
  description   = local.subnets.ml_platform.description

  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# ─── Firewall Rules ─────────────────────────────────────────────────────────

# Deny all ingress by default
resource "google_compute_firewall" "deny_all_ingress" {
  name    = "${local.name_prefix}-deny-all-ingress"
  network = google_compute_network.main.name

  priority  = 65534
  direction = "INGRESS"

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
  description   = "Default deny all ingress — HIPAA zero-trust baseline"
}

# Allow internal VPC traffic
resource "google_compute_firewall" "allow_internal" {
  name    = "${local.name_prefix}-allow-internal"
  network = google_compute_network.main.name

  priority  = 1000
  direction = "INGRESS"

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

  source_ranges = [
    local.subnets.gke.ip_cidr_range,
    local.subnets.database.ip_cidr_range,
    local.subnets.analytics.ip_cidr_range,
    local.subnets.ml_platform.ip_cidr_range,
    local.subnets.gke.pod_cidr,
    local.subnets.gke.service_cidr,
  ]

  description = "Allow internal VPC communication"
}

# Allow cross-cloud traffic (from AWS and Azure VPN)
resource "google_compute_firewall" "allow_cross_cloud" {
  name    = "${local.name_prefix}-allow-cross-cloud"
  network = google_compute_network.main.name

  priority  = 1100
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["443", "8443", "15443", "6443"] # HTTPS, Istio, K8s API
  }

  allow {
    protocol = "tcp"
    ports    = ["5432", "6379", "27017"] # PostgreSQL, Redis, Cosmos
  }

  source_ranges = [var.aws_vpc_cidr, var.azure_vnet_cidr]
  description   = "Allow cross-cloud traffic from AWS and Azure VPN tunnels"
}

# Allow GKE health checks
resource "google_compute_firewall" "allow_health_checks" {
  name    = "${local.name_prefix}-allow-health-checks"
  network = google_compute_network.main.name

  priority  = 900
  direction = "INGRESS"

  allow {
    protocol = "tcp"
  }

  source_ranges = [
    "130.211.0.0/22",  # Google health check probes
    "35.191.0.0/16",   # Google health check probes
  ]

  target_tags = ["gke-node"]
  description = "Allow Google health check probes for GKE and load balancers"
}

# Allow IAP (Identity-Aware Proxy) for secure SSH
resource "google_compute_firewall" "allow_iap" {
  name    = "${local.name_prefix}-allow-iap-ssh"
  network = google_compute_network.main.name

  priority  = 800
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"] # IAP source range
  description   = "Allow SSH via IAP only — no direct SSH access (zero-trust)"
}

# ─── Cloud NAT (Controlled Outbound — No External IPs on VMs) ───────────────

resource "google_compute_router" "main" {
  name    = "${local.name_prefix}-cloud-router"
  region  = var.gcp_region
  network = google_compute_network.main.id

  bgp {
    asn = 65534

    advertise_mode    = "CUSTOM"
    advertised_groups = ["ALL_SUBNETS"]

    # Advertise custom routes to cross-cloud VPN peers
    advertised_ip_ranges {
      range       = local.subnets.gke.ip_cidr_range
      description = "GKE subnet"
    }
    advertised_ip_ranges {
      range       = local.subnets.gke.pod_cidr
      description = "GKE pod CIDR"
    }
  }
}

resource "google_compute_router_nat" "main" {
  name                               = "${local.name_prefix}-cloud-nat"
  router                             = google_compute_router.main.name
  region                             = var.gcp_region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ALL" # Log all NAT translations for HIPAA audit
  }

  min_ports_per_vm = 256
}

# ─── HA VPN to AWS ──────────────────────────────────────────────────────────

resource "google_compute_ha_vpn_gateway" "to_aws" {
  count = var.cross_cloud_vpn_config.aws_to_gcp_enabled ? 1 : 0

  name    = "${local.name_prefix}-vpn-gw-aws"
  region  = var.gcp_region
  network = google_compute_network.main.id
}

# ─── HA VPN to Azure ────────────────────────────────────────────────────────

resource "google_compute_ha_vpn_gateway" "to_azure" {
  count = var.cross_cloud_vpn_config.azure_to_gcp_enabled ? 1 : 0

  name    = "${local.name_prefix}-vpn-gw-azure"
  region  = var.gcp_region
  network = google_compute_network.main.id
}

# ─── Private Service Access (for Cloud SQL, etc.) ───────────────────────────

resource "google_compute_global_address" "private_services" {
  name          = "${local.name_prefix}-private-services"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 20
  network       = google_compute_network.main.id
}

resource "google_service_networking_connection" "private_services" {
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services.name]
}

# ─── Outputs ─────────────────────────────────────────────────────────────────

output "vpc_id" {
  description = "GCP VPC network ID"
  value       = google_compute_network.main.id
}

output "vpc_name" {
  description = "GCP VPC network name"
  value       = google_compute_network.main.name
}

output "gke_subnet_id" {
  description = "GKE subnet self link"
  value       = google_compute_subnetwork.gke.id
}

output "gke_subnet_name" {
  description = "GKE subnet name"
  value       = google_compute_subnetwork.gke.name
}

output "gke_pod_range_name" {
  description = "GKE pod secondary range name"
  value       = "${local.name_prefix}-gke-pods"
}

output "gke_service_range_name" {
  description = "GKE service secondary range name"
  value       = "${local.name_prefix}-gke-services"
}

output "cloud_router_name" {
  description = "Cloud Router name"
  value       = google_compute_router.main.name
}

output "vpn_gateway_aws_id" {
  description = "HA VPN Gateway ID for AWS connectivity"
  value       = try(google_compute_ha_vpn_gateway.to_aws[0].id, null)
}

output "vpn_gateway_azure_id" {
  description = "HA VPN Gateway ID for Azure connectivity"
  value       = try(google_compute_ha_vpn_gateway.to_azure[0].id, null)
}
