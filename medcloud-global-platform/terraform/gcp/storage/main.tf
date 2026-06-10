# ─────────────────────────────────────────────────────────────────────────────
# GCP Storage — Data Lake, ML Artifacts, Cross-Cloud Transfer
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
    prefix = "gcp/storage"
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ─── Data Lake — Raw Ingestion Zone ─────────────────────────────────────

resource "google_storage_bucket" "raw_zone" {
  name     = "${local.name_prefix}-raw-zone-${var.gcp_project_id}"
  location = "US"

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition { age = 30 }
    action { type = "SetStorageClass"; storage_class = "NEARLINE" }
  }

  lifecycle_rule {
    condition { age = 90 }
    action { type = "SetStorageClass"; storage_class = "COLDLINE" }
  }

  labels = {
    environment = var.environment
    data_class  = "raw-ingestion"
    zone        = "raw"
  }
}

# ─── Data Lake — Processed/Curated Zone ─────────────────────────────────

resource "google_storage_bucket" "curated_zone" {
  name     = "${local.name_prefix}-curated-zone-${var.gcp_project_id}"
  location = "US"

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition { age = 180 }
    action { type = "SetStorageClass"; storage_class = "NEARLINE" }
  }

  labels = {
    environment = var.environment
    data_class  = "de-identified"
    zone        = "curated"
  }
}

# ─── Model Artifacts Bucket ─────────────────────────────────────────────

resource "google_storage_bucket" "model_artifacts" {
  name     = "${local.name_prefix}-model-artifacts-${var.gcp_project_id}"
  location = "US"

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  labels = {
    environment = var.environment
    purpose     = "ml-model-artifacts"
  }
}

# ─── Storage Transfer Service (Azure → GCP data pipeline) ───────────────

resource "google_storage_transfer_job" "azure_to_gcp" {
  description = "Transfer de-identified medical telemetry from Azure Blob to GCP raw zone"
  project     = var.gcp_project_id

  transfer_spec {
    azure_blob_storage_data_source {
      storage_account = "medcloudprodmedimages"
      container       = "anonymized-exports"
      azure_credentials {
        sas_token = "" # Set via Secret Manager
      }
    }

    gcs_data_sink {
      bucket_name = google_storage_bucket.raw_zone.name
      path        = "azure-imports/"
    }

    transfer_options {
      overwrite_objects_already_existing_in_sink = false
      delete_objects_from_source_after_transfer  = false
    }
  }

  schedule {
    schedule_start_date {
      year  = 2024
      month = 1
      day   = 1
    }
    start_time_of_day {
      hours   = 2
      minutes = 0
      seconds = 0
      nanos   = 0
    }
    repeat_interval = "86400s" # Daily
  }
}

# ─── Outputs ─────────────────────────────────────────────────────────────

output "raw_zone_bucket" {
  value = google_storage_bucket.raw_zone.name
}

output "curated_zone_bucket" {
  value = google_storage_bucket.curated_zone.name
}

output "model_artifacts_bucket" {
  value = google_storage_bucket.model_artifacts.name
}
