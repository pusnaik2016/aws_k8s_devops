# =============================================================================
# GCP AlloyDB — Compliance Audit Database
# =============================================================================

resource "google_alloydb_cluster" "main" {
  cluster_id = "${local.name_prefix}-alloydb"
  location   = var.region

  network_config {
    network = google_compute_network.main.id
  }

  encryption_config {
    kms_key_name = google_kms_crypto_key.alloydb.id
  }

  automated_backup_policy {
    location      = var.region
    backup_window = "3600s" # 1 hour window
    enabled       = true

    weekly_schedule {
      days_of_week = ["SUNDAY"]
      start_times {
        hours   = 3
        minutes = 0
        seconds = 0
        nanos   = 0
      }
    }

    quantity_based_retention {
      count = 35 # HIPAA: 35-day retention
    }
  }

  continuous_backup_config {
    enabled              = true
    recovery_window_days = 14
  }

  labels = local.labels

  depends_on = [
    google_service_networking_connection.private_services,
    google_kms_crypto_key_iam_member.alloydb_encrypt,
  ]
}

resource "google_alloydb_instance" "primary" {
  cluster       = google_alloydb_cluster.main.name
  instance_id   = "${local.name_prefix}-alloydb-primary"
  instance_type = "PRIMARY"

  machine_config {
    cpu_count = var.alloydb_cpu_count
  }

  database_flags = {
    "pgaudit.log"                 = "all"
    "log_min_duration_statement"  = "1000"
    "log_statement"               = "all"
  }

  labels = local.labels
}

resource "google_alloydb_instance" "read_pool" {
  cluster       = google_alloydb_cluster.main.name
  instance_id   = "${local.name_prefix}-alloydb-read-pool"
  instance_type = "READ_POOL"

  read_pool_config {
    node_count = 2
  }

  machine_config {
    cpu_count = 2
  }

  labels = merge(local.labels, {
    "purpose" = "compliance-queries"
  })

  depends_on = [google_alloydb_instance.primary]
}
