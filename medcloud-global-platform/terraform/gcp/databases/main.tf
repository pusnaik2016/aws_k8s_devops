# ─────────────────────────────────────────────────────────────────────────────
# GCP Databases — Cloud SQL (PostgreSQL), Cloud Bigtable
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
    prefix = "gcp/databases"
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

data "terraform_remote_state" "networking" {
  backend = "gcs"
  config = {
    bucket = "medcloud-terraform-state-gcp"
    prefix = "gcp/networking"
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  vpc_id      = data.terraform_remote_state.networking.outputs.vpc_id
  network     = data.terraform_remote_state.networking.outputs.vpc_self_link
}

# ─── Cloud SQL (PostgreSQL) — Analytics Metadata ────────────────────────

resource "google_sql_database_instance" "analytics_meta" {
  name                = "${local.name_prefix}-analytics-sql"
  database_version    = "POSTGRES_15"
  region              = var.gcp_region
  deletion_protection = var.environment == "prod"

  settings {
    tier              = var.environment == "prod" ? "db-custom-4-16384" : "db-custom-2-8192"
    availability_type = var.environment == "prod" ? "REGIONAL" : "ZONAL"
    disk_autoresize   = true
    disk_size         = 50
    disk_type         = "PD_SSD"

    ip_configuration {
      ipv4_enabled    = false
      private_network = local.network
      require_ssl     = true
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      start_time                     = "03:00"
      transaction_log_retention_days = 7

      backup_retention_settings {
        retained_backups = var.environment == "prod" ? 30 : 7
      }
    }

    maintenance_window {
      day          = 7 # Sunday
      hour         = 4
      update_track = "stable"
    }

    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }

    insights_config {
      query_insights_enabled  = true
      query_plans_per_minute  = 5
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = true
    }
  }

  depends_on = [google_service_networking_connection.private]
}

resource "google_service_networking_connection" "private" {
  network                 = local.network
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.sql_private_ip.name]
}

resource "google_compute_global_address" "sql_private_ip" {
  name          = "${local.name_prefix}-sql-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 20
  network       = local.network
}

resource "google_sql_database" "analytics" {
  name     = "analytics_metadata"
  instance = google_sql_database_instance.analytics_meta.name
}

resource "google_sql_user" "analytics_admin" {
  name     = "analytics_admin"
  instance = google_sql_database_instance.analytics_meta.name
  password = "CHANGE_ME" # Use Secret Manager in production
}

# ─── Cloud Bigtable — Time-Series IoT/Telemetry ─────────────────────────

resource "google_bigtable_instance" "telemetry" {
  name                = "${local.name_prefix}-bigtable-telemetry"
  deletion_protection = var.environment == "prod"

  cluster {
    cluster_id   = "${local.name_prefix}-bt-cluster-1"
    zone         = "${var.gcp_region}-a"
    num_nodes    = var.environment == "prod" ? 3 : 1
    storage_type = "SSD"
  }

  dynamic "cluster" {
    for_each = var.environment == "prod" ? [1] : []
    content {
      cluster_id   = "${local.name_prefix}-bt-cluster-2"
      zone         = "${var.gcp_region}-b"
      num_nodes    = 3
      storage_type = "SSD"
    }
  }

  labels = {
    environment = var.environment
    data_class  = "anonymized-telemetry"
  }
}

resource "google_bigtable_table" "device_telemetry" {
  name          = "device_telemetry"
  instance_name = google_bigtable_instance.telemetry.name

  column_family {
    family = "vitals"    # heart_rate, blood_pressure, temperature
  }

  column_family {
    family = "device"    # device_type, firmware_version, battery
  }

  column_family {
    family = "location"  # anonymized geo region
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "google_bigtable_gc_policy" "device_telemetry_vitals" {
  instance_name = google_bigtable_instance.telemetry.name
  table         = google_bigtable_table.device_telemetry.name
  column_family = "vitals"

  max_age {
    duration = var.environment == "prod" ? "8760h" : "720h" # 1 year / 30 days
  }
}

# ─── Outputs ─────────────────────────────────────────────────────────────

output "cloud_sql_connection_name" {
  value = google_sql_database_instance.analytics_meta.connection_name
}

output "cloud_sql_private_ip" {
  value = google_sql_database_instance.analytics_meta.private_ip_address
}

output "bigtable_instance_id" {
  value = google_bigtable_instance.telemetry.id
}
