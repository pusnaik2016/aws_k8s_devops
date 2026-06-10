# ─────────────────────────────────────────────────────────────────────────────
# GCP ML Platform — Vertex AI Pipelines, Model Registry, Endpoints
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
    prefix = "gcp/ml-platform"
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ─── Vertex AI Workbench (Managed Notebooks for Data Science) ───────────

resource "google_workbench_instance" "ml_notebook" {
  name     = "${local.name_prefix}-ml-workbench"
  location = "${var.gcp_region}-a"

  gce_setup {
    machine_type = var.environment == "prod" ? "n1-standard-8" : "n1-standard-4"

    accelerator_configs {
      type  = "NVIDIA_TESLA_T4"
      count = 1
    }

    boot_disk {
      disk_type    = "PD_SSD"
      disk_size_gb = 200
    }

    data_disks {
      disk_type    = "PD_SSD"
      disk_size_gb = 500
    }

    network_interfaces {
      network  = "projects/${var.gcp_project_id}/global/networks/${local.name_prefix}-vpc"
      subnet   = "projects/${var.gcp_project_id}/regions/${var.gcp_region}/subnetworks/${local.name_prefix}-analytics-subnet"
      nic_type = "GVNIC"
    }

    metadata = {
      idle-timeout-seconds = "3600"
    }

    disable_public_ip = true

    service_accounts {
      email = google_service_account.ml_workbench.email
    }
  }

  labels = {
    environment = var.environment
    purpose     = "ml-training"
  }
}

resource "google_service_account" "ml_workbench" {
  account_id   = "${local.name_prefix}-ml-workbench"
  display_name = "Vertex AI Workbench — ML Training"
}

resource "google_project_iam_member" "ml_workbench_bq" {
  project = var.gcp_project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.ml_workbench.email}"
}

resource "google_project_iam_member" "ml_workbench_vertex" {
  project = var.gcp_project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.ml_workbench.email}"
}

resource "google_project_iam_member" "ml_workbench_storage" {
  project = var.gcp_project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.ml_workbench.email}"
}

# ─── Vertex AI Pipelines Bucket ─────────────────────────────────────────

resource "google_storage_bucket" "ml_pipelines" {
  name     = "${local.name_prefix}-ml-pipelines-${var.gcp_project_id}"
  location = "US"

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 180
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  labels = {
    environment = var.environment
    purpose     = "ml-pipelines"
  }
}

# ─── Model Serving Service Account (for GKE AI Gateway) ─────────────────

resource "google_service_account" "model_serving" {
  account_id   = "${local.name_prefix}-model-serving"
  display_name = "Vertex AI Model Serving — GKE AI Gateway"
}

resource "google_project_iam_member" "model_serving_vertex" {
  project = var.gcp_project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.model_serving.email}"
}

resource "google_project_iam_member" "model_serving_featurestore" {
  project = var.gcp_project_id
  role    = "roles/aiplatform.featurestoreUser"
  member  = "serviceAccount:${google_service_account.model_serving.email}"
}

# Workload Identity binding — allows GKE pods to use this SA
resource "google_service_account_iam_member" "model_serving_wi" {
  service_account_id = google_service_account.model_serving.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.gcp_project_id}.svc.id.goog[medcloud/ai-gateway]"
}

# ─── Outputs ─────────────────────────────────────────────────────────────

output "ml_workbench_name" {
  value = google_workbench_instance.ml_notebook.name
}

output "ml_pipelines_bucket" {
  value = google_storage_bucket.ml_pipelines.name
}

output "model_serving_sa_email" {
  value = google_service_account.model_serving.email
}
