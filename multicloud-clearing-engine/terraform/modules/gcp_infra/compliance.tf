# =============================================================================
# GCP Compliance — Audit Logs, Log Sinks, Security Command Center
# =============================================================================

# --- Audit Log Sink to BigQuery ---
resource "google_logging_project_sink" "audit_to_bigquery" {
  name        = "${local.name_prefix}-audit-sink"
  project     = var.project_id
  destination = "bigquery.googleapis.com/projects/${var.project_id}/datasets/${google_bigquery_dataset.compliance_audit.dataset_id}"
  filter      = "logName:\"logs/cloudaudit.googleapis.com\""

  unique_writer_identity = true

  bigquery_options {
    use_partitioned_tables = true
  }
}

# Grant sink writer access to BigQuery
resource "google_bigquery_dataset_iam_member" "audit_sink_writer" {
  dataset_id = google_bigquery_dataset.compliance_audit.dataset_id
  project    = var.project_id
  role       = "roles/bigquery.dataEditor"
  member     = google_logging_project_sink.audit_to_bigquery.writer_identity
}

# --- Organization Policy Constraints ---
resource "google_project_organization_policy" "restrict_locations" {
  count   = var.enable_gdpr ? 1 : 0
  project = var.project_id
  constraint = "constraints/gcp.resourceLocations"

  list_policy {
    allow {
      values = [
        "in:us-locations",
        "in:eu-locations",
      ]
    }
  }
}

resource "google_project_organization_policy" "require_os_login" {
  project    = var.project_id
  constraint = "constraints/compute.requireOsLogin"

  boolean_policy {
    enforced = true
  }
}

resource "google_project_organization_policy" "disable_serial_port" {
  project    = var.project_id
  constraint = "constraints/compute.disableSerialPortAccess"

  boolean_policy {
    enforced = true
  }
}

# --- Data Access Audit Logs (Read/Write) ---
resource "google_project_iam_audit_config" "all_services" {
  project = var.project_id
  service = "allServices"

  audit_log_config {
    log_type = "ADMIN_READ"
  }

  audit_log_config {
    log_type = "DATA_READ"
  }

  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

# --- Monitoring Alert for Compliance Drift ---
resource "google_monitoring_alert_policy" "config_drift" {
  display_name = "${local.name_prefix}-config-drift-alert"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "IAM Policy Changed"
    condition_matched_log {
      filter = "protoPayload.methodName=\"SetIamPolicy\""
    }
  }

  alert_strategy {
    notification_rate_limit {
      period = "300s"
    }
  }

  notification_channels = []

  documentation {
    content   = "An IAM policy was modified. Review the change for compliance impact."
    mime_type = "text/markdown"
  }
}
