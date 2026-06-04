# =============================================================================
# GCP BigQuery — Compliance Audit & GDPR Anonymized Storage
# =============================================================================

# --- Compliance Audit Dataset (US Multi-Region) ---
resource "google_bigquery_dataset" "compliance_audit" {
  dataset_id  = "compliance_audit_logs"
  description = "Immutable compliance audit trail — SOX 7-year retention"
  location    = "US"
  project     = var.project_id

  default_table_expiration_ms     = null # No expiration (SOX)
  default_partition_expiration_ms = null

  default_encryption_configuration {
    kms_key_name = google_kms_crypto_key.bigquery.id
  }

  access {
    role          = "OWNER"
    special_group = "projectOwners"
  }

  access {
    role          = "READER"
    special_group = "projectReaders"
  }

  labels = local.labels

  depends_on = [google_project_service.apis]
}

# --- GDPR Anonymized Dataset (EU Multi-Region for Data Sovereignty) ---
resource "google_bigquery_dataset" "anonymized_gdpr" {
  dataset_id  = "anonymized_gdpr_data"
  description = "GDPR-compliant anonymized PII storage — EU data sovereignty"
  location    = "EU"
  project     = var.project_id

  default_encryption_configuration {
    kms_key_name = google_kms_crypto_key.bigquery_eu.id
  }

  access {
    role          = "OWNER"
    special_group = "projectOwners"
  }

  labels = merge(local.labels, {
    "gdpr-compliant"  = "true"
    "data-sovereignty" = "eu"
  })

  depends_on = [google_project_service.apis]
}

# --- Tables ---
resource "google_bigquery_table" "transaction_audit_trail" {
  dataset_id = google_bigquery_dataset.compliance_audit.dataset_id
  table_id   = "transaction_audit_trail"
  project    = var.project_id

  time_partitioning {
    type  = "DAY"
    field = "event_timestamp"
  }

  clustering = ["cloud_provider", "transaction_type"]

  schema = jsonencode([
    { name = "event_id",          type = "STRING",    mode = "REQUIRED" },
    { name = "event_timestamp",   type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "cloud_provider",    type = "STRING",    mode = "REQUIRED" },
    { name = "transaction_type",  type = "STRING",    mode = "REQUIRED" },
    { name = "transaction_id",    type = "STRING",    mode = "REQUIRED" },
    { name = "amount_cents",      type = "INTEGER",   mode = "REQUIRED" },
    { name = "currency",          type = "STRING",    mode = "REQUIRED" },
    { name = "status",            type = "STRING",    mode = "REQUIRED" },
    { name = "source_system",     type = "STRING",    mode = "NULLABLE" },
    { name = "actor_id",          type = "STRING",    mode = "NULLABLE" },
    { name = "ip_address_hash",   type = "STRING",    mode = "NULLABLE" },
    { name = "metadata",          type = "JSON",      mode = "NULLABLE" },
  ])

  labels = local.labels
}

resource "google_bigquery_table" "pii_access_log" {
  dataset_id = google_bigquery_dataset.compliance_audit.dataset_id
  table_id   = "pii_access_log"
  project    = var.project_id

  time_partitioning {
    type  = "DAY"
    field = "access_timestamp"
  }

  schema = jsonencode([
    { name = "access_id",        type = "STRING",    mode = "REQUIRED" },
    { name = "access_timestamp", type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "accessor_id",      type = "STRING",    mode = "REQUIRED" },
    { name = "accessor_role",    type = "STRING",    mode = "REQUIRED" },
    { name = "resource_type",    type = "STRING",    mode = "REQUIRED" },
    { name = "resource_id",      type = "STRING",    mode = "REQUIRED" },
    { name = "action",           type = "STRING",    mode = "REQUIRED" },
    { name = "justification",    type = "STRING",    mode = "NULLABLE" },
    { name = "cloud_provider",   type = "STRING",    mode = "REQUIRED" },
  ])

  labels = local.labels
}

resource "google_bigquery_table" "config_drift_events" {
  dataset_id = google_bigquery_dataset.compliance_audit.dataset_id
  table_id   = "config_drift_events"
  project    = var.project_id

  time_partitioning {
    type  = "DAY"
    field = "detected_at"
  }

  schema = jsonencode([
    { name = "drift_id",        type = "STRING",    mode = "REQUIRED" },
    { name = "detected_at",     type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "cloud_provider",  type = "STRING",    mode = "REQUIRED" },
    { name = "resource_type",   type = "STRING",    mode = "REQUIRED" },
    { name = "resource_id",     type = "STRING",    mode = "REQUIRED" },
    { name = "expected_config", type = "JSON",      mode = "REQUIRED" },
    { name = "actual_config",   type = "JSON",      mode = "REQUIRED" },
    { name = "severity",        type = "STRING",    mode = "REQUIRED" },
    { name = "remediated",      type = "BOOLEAN",   mode = "REQUIRED" },
  ])

  labels = local.labels
}
