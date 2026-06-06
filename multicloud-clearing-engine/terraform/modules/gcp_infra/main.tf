# =============================================================================
# GCP INFRASTRUCTURE MODULE — Compliance & Analytics Layer
# =============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  labels = merge(var.common_labels, {
    module      = "gcp-infra"
    cloud       = "gcp"
    environment = var.environment
    managed-by  = "terraform"
  })

  required_apis = [
    "container.googleapis.com",
    "alloydb.googleapis.com",
    "bigquery.googleapis.com",
    "compute.googleapis.com",
    "cloudkms.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "servicenetworking.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "securitycenter.googleapis.com",
    "binaryauthorization.googleapis.com",
    "dns.googleapis.com",
  ]
}

resource "google_project_service" "apis" {
  for_each = toset(local.required_apis)

  project = var.project_id
  service = each.value

  disable_dependent_services = false
  disable_on_destroy         = false
}
