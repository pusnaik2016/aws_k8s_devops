# =============================================================================
# GCP Cloud KMS — Encryption Keys
# =============================================================================

resource "google_kms_key_ring" "main" {
  name     = "${local.name_prefix}-keyring"
  location = var.region
  project  = var.project_id

  depends_on = [google_project_service.apis]
}

# EU keyring for GDPR data sovereignty
resource "google_kms_key_ring" "eu" {
  name     = "${local.name_prefix}-keyring-eu"
  location = "europe"
  project  = var.project_id

  depends_on = [google_project_service.apis]
}

# --- Crypto Keys ---
resource "google_kms_crypto_key" "gke" {
  name            = "${local.name_prefix}-gke-key"
  key_ring        = google_kms_key_ring.main.id
  rotation_period = "7776000s" # 90 days
  purpose         = "ENCRYPT_DECRYPT"

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = "SOFTWARE"
  }
}

resource "google_kms_crypto_key" "alloydb" {
  name            = "${local.name_prefix}-alloydb-key"
  key_ring        = google_kms_key_ring.main.id
  rotation_period = "7776000s"
  purpose         = "ENCRYPT_DECRYPT"

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = "SOFTWARE"
  }
}

resource "google_kms_crypto_key" "bigquery" {
  name            = "${local.name_prefix}-bigquery-key"
  key_ring        = google_kms_key_ring.main.id
  rotation_period = "7776000s"
  purpose         = "ENCRYPT_DECRYPT"

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = "SOFTWARE"
  }
}

resource "google_kms_crypto_key" "bigquery_eu" {
  name            = "${local.name_prefix}-bigquery-eu-key"
  key_ring        = google_kms_key_ring.eu.id
  rotation_period = "7776000s"
  purpose         = "ENCRYPT_DECRYPT"

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = "SOFTWARE"
  }
}

# --- IAM Bindings for Service Agents ---
data "google_project" "current" {
  project_id = var.project_id
}

# GKE encryption
resource "google_kms_crypto_key_iam_member" "gke_encrypt" {
  crypto_key_id = google_kms_crypto_key.gke.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.current.number}@container-engine-robot.iam.gserviceaccount.com"
}

# AlloyDB encryption
resource "google_kms_crypto_key_iam_member" "alloydb_encrypt" {
  crypto_key_id = google_kms_crypto_key.alloydb.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-alloydb.iam.gserviceaccount.com"
}

# BigQuery encryption
resource "google_kms_crypto_key_iam_member" "bigquery_encrypt" {
  crypto_key_id = google_kms_crypto_key.bigquery.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:bq-${data.google_project.current.number}@bigquery-encryption.iam.gserviceaccount.com"
}

resource "google_kms_crypto_key_iam_member" "bigquery_eu_encrypt" {
  crypto_key_id = google_kms_crypto_key.bigquery_eu.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:bq-${data.google_project.current.number}@bigquery-encryption.iam.gserviceaccount.com"
}
