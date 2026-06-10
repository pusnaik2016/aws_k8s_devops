# ─────────────────────────────────────────────────────────────────────────────
# GCP GKE Cluster — Analytics & ML Ops Compute
# ─────────────────────────────────────────────────────────────────────────────
# HIPAA-compliant GKE with:
# - Private cluster (no public endpoint in prod)
# - Workload Identity for pod-level GCP IAM
# - Binary Authorization for signed container images
# - GKE Sandbox (gVisor) for untrusted workloads
# - Shielded GKE Nodes (Secure Boot, vTPM)
# - Dataplane V2 (eBPF-based networking)
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
    prefix = "gcp/gke"
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# ─── Data Sources ────────────────────────────────────────────────────────────

data "terraform_remote_state" "networking" {
  backend = "gcs"
  config = {
    bucket = "medcloud-terraform-state-gcp"
    prefix = "gcp/networking"
  }
}

# ─── Locals ──────────────────────────────────────────────────────────────────

locals {
  name_prefix  = "${var.project_name}-${var.environment}"
  cluster_name = "${local.name_prefix}-gke"
  vpc_name     = data.terraform_remote_state.networking.outputs.vpc_name
  subnet_name  = data.terraform_remote_state.networking.outputs.gke_subnet_name
  pod_range    = data.terraform_remote_state.networking.outputs.gke_pod_range_name
  svc_range    = data.terraform_remote_state.networking.outputs.gke_service_range_name
}

# ─── GKE Service Account ────────────────────────────────────────────────────

resource "google_service_account" "gke_nodes" {
  account_id   = "${local.name_prefix}-gke-nodes"
  display_name = "GKE Node Service Account - ${var.environment}"
  description  = "Least-privilege SA for GKE nodes (no default compute SA)"
}

# Minimal permissions for nodes
resource "google_project_iam_member" "gke_node_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/artifactregistry.reader",
  ])

  project = var.gcp_project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# ─── GKE Cluster ────────────────────────────────────────────────────────────

resource "google_container_cluster" "main" {
  name     = local.cluster_name
  location = var.gcp_region

  # Use release channels for auto-upgrades
  release_channel {
    channel = var.environment == "prod" ? "STABLE" : "REGULAR"
  }

  network    = local.vpc_name
  subnetwork = local.subnet_name

  # VPC-native cluster with alias IPs
  ip_allocation_policy {
    cluster_secondary_range_name  = local.pod_range
    services_secondary_range_name = local.svc_range
  }

  # HIPAA: Private cluster
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = var.environment == "prod" ? true : false
    master_ipv4_cidr_block  = "172.16.0.0/28"

    master_global_access_config {
      enabled = true # Allow access from any region
    }
  }

  # Authorized networks for API access
  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.environment == "prod" ? [] : [1]
      content {
        cidr_block   = "0.0.0.0/0"
        display_name = "All (dev only)"
      }
    }

    # Allow cross-cloud access
    cidr_blocks {
      cidr_block   = var.aws_vpc_cidr
      display_name = "AWS VPC"
    }
    cidr_blocks {
      cidr_block   = var.azure_vnet_cidr
      display_name = "Azure VNet"
    }
  }

  # Dataplane V2 (eBPF — Cilium-based, replaces kube-proxy)
  datapath_provider = "ADVANCED_DATAPATH"

  # Enable network policy enforcement
  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  # Workload Identity (IRSA equivalent)
  workload_identity_config {
    workload_pool = "${var.gcp_project_id}.svc.id.goog"
  }

  # HIPAA: Binary Authorization
  binary_authorization {
    evaluation_mode = var.environment == "prod" ? "PROJECT_SINGLETON_POLICY_ENFORCE" : "DISABLED"
  }

  # Shielded nodes
  node_config {
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  # HIPAA: Database encryption with CMEK
  database_encryption {
    state    = "ENCRYPTED"
    key_name = google_kms_crypto_key.gke_etcd.id
  }

  # Logging and monitoring
  logging_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "WORKLOADS",
      "APISERVER",
      "CONTROLLER_MANAGER",
      "SCHEDULER",
    ]
  }

  monitoring_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "APISERVER",
      "CONTROLLER_MANAGER",
      "SCHEDULER",
    ]

    managed_prometheus {
      enabled = true
    }
  }

  # Security posture
  security_posture_config {
    mode               = "BASIC"
    vulnerability_mode = "VULNERABILITY_ENTERPRISE"
  }

  # Maintenance window
  maintenance_policy {
    recurring_window {
      start_time = "2024-01-01T02:00:00Z"
      end_time   = "2024-01-01T06:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=SA"
    }
  }

  # Remove default node pool — use separately managed pools
  remove_default_node_pool = true
  initial_node_count       = 1

  # Cost management
  cost_management_config {
    enabled = true
  }

  # Gateway API
  gateway_api_config {
    channel = "CHANNEL_STANDARD"
  }

  deletion_protection = var.environment == "prod" ? true : false
}

# ─── KMS Key for GKE etcd Encryption ────────────────────────────────────────

resource "google_kms_key_ring" "gke" {
  name     = "${local.cluster_name}-keyring"
  location = var.gcp_region
}

resource "google_kms_crypto_key" "gke_etcd" {
  name            = "${local.cluster_name}-etcd-key"
  key_ring        = google_kms_key_ring.gke.id
  rotation_period = "7776000s" # 90 days

  lifecycle {
    prevent_destroy = false
  }
}

# Grant GKE service agent access to the KMS key
resource "google_kms_crypto_key_iam_member" "gke_etcd" {
  crypto_key_id = google_kms_crypto_key.gke_etcd.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.current.number}@container-engine-robot.iam.gserviceaccount.com"
}

data "google_project" "current" {
  project_id = var.gcp_project_id
}

# ─── Analytics Node Pool (BigQuery connectors, Dataflow) ────────────────────

resource "google_container_node_pool" "analytics" {
  name     = "analytics"
  location = var.gcp_region
  cluster  = google_container_cluster.main.name

  autoscaling {
    min_node_count = var.node_count.min
    max_node_count = var.node_count.max
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.node_instance_type.gcp
    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    disk_size_gb = 100
    disk_type    = "pd-balanced"
    image_type   = "COS_CONTAINERD"

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    labels = {
      role     = "analytics"
      cloud    = "gcp"
      workload = "data-analytics"
    }

    taint {
      key    = "workload"
      value  = "analytics"
      effect = "NO_SCHEDULE"
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}

# ─── ML Platform Node Pool (Vertex AI, model serving) ───────────────────────

resource "google_container_node_pool" "ml_platform" {
  name     = "ml-platform"
  location = var.gcp_region
  cluster  = google_container_cluster.main.name

  autoscaling {
    min_node_count = 0
    max_node_count = var.environment == "prod" ? 5 : 2
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.environment == "prod" ? "n1-standard-8" : "e2-standard-4"
    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    disk_size_gb = 200
    disk_type    = "pd-ssd"
    image_type   = "COS_CONTAINERD"

    # GPU for prod ML workloads
    dynamic "guest_accelerator" {
      for_each = var.environment == "prod" ? [1] : []
      content {
        type  = "nvidia-tesla-t4"
        count = 1
        gpu_driver_installation_config {
          gpu_driver_version = "LATEST"
        }
      }
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    # GKE Sandbox (gVisor) for ML workloads handling untrusted data
    sandbox_config {
      sandbox_type = "gvisor"
    }

    labels = {
      role     = "ml-platform"
      cloud    = "gcp"
      workload = "ai-ml"
    }

    taint {
      key    = "workload"
      value  = "ml"
      effect = "NO_SCHEDULE"
    }
  }
}

# ─── System Node Pool ───────────────────────────────────────────────────────

resource "google_container_node_pool" "system" {
  name     = "system"
  location = var.gcp_region
  cluster  = google_container_cluster.main.name

  autoscaling {
    min_node_count = 2
    max_node_count = 4
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = "e2-standard-4"
    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    disk_size_gb = 100
    disk_type    = "pd-balanced"
    image_type   = "COS_CONTAINERD"

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    labels = {
      role  = "system"
      cloud = "gcp"
    }

    taint {
      key    = "CriticalAddonsOnly"
      value  = "true"
      effect = "NO_SCHEDULE"
    }
  }
}

# ─── Outputs ─────────────────────────────────────────────────────────────────

output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.main.name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.main.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "GKE cluster CA certificate"
  value       = google_container_cluster.main.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "workload_identity_pool" {
  description = "Workload identity pool for GKE"
  value       = "${var.gcp_project_id}.svc.id.goog"
}

output "node_service_account" {
  description = "GKE node service account email"
  value       = google_service_account.gke_nodes.email
}
