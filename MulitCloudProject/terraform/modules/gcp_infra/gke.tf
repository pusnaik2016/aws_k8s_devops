# =============================================================================
# GCP GKE — Analytics Compute Cluster
# =============================================================================

resource "google_container_cluster" "main" {
  name     = "${local.name_prefix}-gke"
  location = var.region

  # Remove default node pool (use separately managed one)
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.main.id
  subnetwork = google_compute_subnetwork.gke_nodes.id

  # Private Cluster
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false # Set true for full private
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0" # Restrict to VPN/bastion IPs in production
      display_name = "All (restrict in production)"
    }
  }

  # IP Allocation
  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-pods"
    services_secondary_range_name = "gke-services"
  }

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Binary Authorization
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  # Network Policy (Calico)
  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  addons_config {
    network_policy_config {
      disabled = false
    }
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
  }

  # Logging & Monitoring
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = true
    }
  }

  # Release Channel
  release_channel {
    channel = "REGULAR"
  }

  # Database Encryption
  database_encryption {
    state    = "ENCRYPTED"
    key_name = google_kms_crypto_key.gke.id
  }

  resource_labels = local.labels

  depends_on = [
    google_project_service.apis,
    google_kms_crypto_key_iam_member.gke_encrypt,
  ]
}

# Node Pool
resource "google_container_node_pool" "analytics" {
  name       = "${local.name_prefix}-analytics-pool"
  cluster    = google_container_cluster.main.id
  location   = var.region

  autoscaling {
    min_node_count = var.gke_node_min
    max_node_count = var.gke_node_max
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = var.gke_node_machine_type
    disk_size_gb = 100
    disk_type    = "pd-ssd"

    # Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Shielded Instance
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    labels = merge(local.labels, {
      "nodepool" = "analytics"
    })

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}
