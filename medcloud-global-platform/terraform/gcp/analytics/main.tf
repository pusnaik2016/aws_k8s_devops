# ─────────────────────────────────────────────────────────────────────────────
# GCP Analytics — BigQuery + Dataflow + Vertex AI
# ─────────────────────────────────────────────────────────────────────────────
# The analytics and ML engine for MedCloud Global:
# - BigQuery: Cross-cloud telemetry aggregation, marketing analytics
# - Vertex AI: Fraud detection, product recommendation models
# - Cloud DLP: PHI/PII data scrubbing before analytics
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
    prefix = "gcp/analytics"
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BigQuery — Analytics Data Warehouse
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Dataset: E-Commerce Transactions (from AWS Aurora via CDC)
resource "google_bigquery_dataset" "ecommerce" {
  dataset_id    = "ecommerce_transactions"
  friendly_name = "E-Commerce Transactions"
  description   = "Aggregated e-commerce transaction data from AWS Aurora (de-identified)"
  location      = "US"

  default_table_expiration_ms    = null
  default_partition_expiration_ms = null

  labels = {
    environment = var.environment
    data_class  = "pci-tokenized"
    source      = "aws-aurora"
  }

  access {
    role          = "OWNER"
    special_group = "projectOwners"
  }

  access {
    role          = "READER"
    special_group = "projectReaders"
  }

  # HIPAA: CMEK encryption
  default_encryption_configuration {
    kms_key_name = google_kms_crypto_key.bigquery.id
  }
}

# Dataset: Medical Telemetry (anonymized from Azure Cosmos DB)
resource "google_bigquery_dataset" "medical_telemetry" {
  dataset_id    = "medical_telemetry"
  friendly_name = "Medical Telemetry"
  description   = "Anonymized medical device and wearable telemetry data"
  location      = "US"

  labels = {
    environment = var.environment
    data_class  = "anonymized-phi"
    source      = "azure-cosmosdb"
  }

  default_encryption_configuration {
    kms_key_name = google_kms_crypto_key.bigquery.id
  }
}

# Dataset: Platform Analytics (cross-cloud observability)
resource "google_bigquery_dataset" "platform_analytics" {
  dataset_id    = "platform_analytics"
  friendly_name = "Platform Analytics"
  description   = "Cross-cloud infrastructure metrics, costs, and performance data"
  location      = "US"

  labels = {
    environment = var.environment
    data_class  = "internal"
    source      = "multi-cloud"
  }

  default_encryption_configuration {
    kms_key_name = google_kms_crypto_key.bigquery.id
  }
}

# Table: Orders (partitioned by date, clustered for query optimization)
resource "google_bigquery_table" "orders" {
  dataset_id          = google_bigquery_dataset.ecommerce.dataset_id
  table_id            = "orders"
  deletion_protection = var.environment == "prod"

  time_partitioning {
    type  = "DAY"
    field = "order_date"
  }

  clustering = ["region", "product_category", "payment_status"]

  schema = jsonencode([
    { name = "order_id",         type = "STRING",    mode = "REQUIRED" },
    { name = "customer_id",      type = "STRING",    mode = "REQUIRED", description = "Tokenized customer ID (no PII)" },
    { name = "order_date",       type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "region",           type = "STRING",    mode = "REQUIRED" },
    { name = "product_category", type = "STRING",    mode = "REQUIRED" },
    { name = "product_id",       type = "STRING",    mode = "REQUIRED" },
    { name = "quantity",         type = "INTEGER",   mode = "REQUIRED" },
    { name = "unit_price",       type = "FLOAT",     mode = "REQUIRED" },
    { name = "total_amount",     type = "FLOAT",     mode = "REQUIRED" },
    { name = "currency",         type = "STRING",    mode = "REQUIRED" },
    { name = "payment_method",   type = "STRING",    mode = "NULLABLE", description = "Tokenized (PCI-DSS)" },
    { name = "payment_status",   type = "STRING",    mode = "REQUIRED" },
    { name = "shipping_country", type = "STRING",    mode = "NULLABLE" },
    { name = "is_prescription",  type = "BOOLEAN",   mode = "REQUIRED" },
  ])

  labels = {
    data_class = "pci-tokenized"
  }
}

# Table: Product Interactions (for recommendation model training)
resource "google_bigquery_table" "product_interactions" {
  dataset_id          = google_bigquery_dataset.ecommerce.dataset_id
  table_id            = "product_interactions"
  deletion_protection = var.environment == "prod"

  time_partitioning {
    type  = "DAY"
    field = "event_timestamp"
  }

  clustering = ["event_type", "product_category"]

  schema = jsonencode([
    { name = "interaction_id",   type = "STRING",    mode = "REQUIRED" },
    { name = "session_id",       type = "STRING",    mode = "REQUIRED" },
    { name = "customer_id",      type = "STRING",    mode = "REQUIRED", description = "Tokenized" },
    { name = "event_timestamp",  type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "event_type",       type = "STRING",    mode = "REQUIRED", description = "view|click|add_to_cart|purchase" },
    { name = "product_id",       type = "STRING",    mode = "REQUIRED" },
    { name = "product_category", type = "STRING",    mode = "REQUIRED" },
    { name = "device_type",      type = "STRING",    mode = "NULLABLE" },
    { name = "geo_country",      type = "STRING",    mode = "NULLABLE" },
  ])
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Cloud Storage — Data Lake Landing Zone
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

resource "google_storage_bucket" "data_lake" {
  name     = "${local.name_prefix}-data-lake-${var.gcp_project_id}"
  location = "US"

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  lifecycle_rule {
    condition {
      age = 365
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }

  encryption {
    default_kms_key_name = google_kms_crypto_key.storage.id
  }

  labels = {
    environment = var.environment
    data_class  = "anonymized"
    compliance  = "hipaa"
  }
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Vertex AI — ML Platform for Fraud Detection & Recommendations
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

resource "google_vertex_ai_dataset" "fraud_detection" {
  display_name        = "fraud-detection-dataset"
  metadata_schema_uri = "gs://google-cloud-aiplatform/schema/dataset/metadata/tabular_1.0.0.yaml"
  region              = var.gcp_region

  labels = {
    environment = var.environment
    model       = "fraud-detection"
  }
}

resource "google_vertex_ai_dataset" "product_recommendations" {
  display_name        = "product-recommendations-dataset"
  metadata_schema_uri = "gs://google-cloud-aiplatform/schema/dataset/metadata/tabular_1.0.0.yaml"
  region              = var.gcp_region

  labels = {
    environment = var.environment
    model       = "recommendations"
  }
}

# Vertex AI Feature Store (for model serving)
resource "google_vertex_ai_featurestore" "main" {
  name   = replace("${local.name_prefix}_featurestore", "-", "_")
  region = var.gcp_region

  online_serving_config {
    fixed_node_count = var.environment == "prod" ? 2 : 1
  }

  force_destroy = var.environment != "prod"

  labels = {
    environment = var.environment
  }
}

# Vertex AI Feature Store Entity Types
resource "google_vertex_ai_featurestore_entitytype" "customer" {
  name         = "customer"
  featurestore = google_vertex_ai_featurestore.main.id
  description  = "Customer features for fraud detection and recommendations"

  monitoring_config {
    snapshot_analysis {
      disabled = false
    }
  }

  labels = {
    data_class = "tokenized-pii"
  }
}

resource "google_vertex_ai_featurestore_entitytype" "product" {
  name         = "product"
  featurestore = google_vertex_ai_featurestore.main.id
  description  = "Product features for recommendation model"

  labels = {
    data_class = "public"
  }
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Cloud DLP — PHI/PII Scrubbing (before data enters analytics)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

resource "google_data_loss_prevention_inspect_template" "phi_detection" {
  parent       = "projects/${var.gcp_project_id}"
  display_name = "MedCloud PHI Detection Template"
  description  = "Detects PHI/PII in data flowing from Azure to GCP analytics"

  inspect_config {
    # Medical info types
    info_types {
      name = "PERSON_NAME"
    }
    info_types {
      name = "PHONE_NUMBER"
    }
    info_types {
      name = "EMAIL_ADDRESS"
    }
    info_types {
      name = "US_SOCIAL_SECURITY_NUMBER"
    }
    info_types {
      name = "CREDIT_CARD_NUMBER"
    }
    info_types {
      name = "DATE_OF_BIRTH"
    }
    info_types {
      name = "STREET_ADDRESS"
    }
    info_types {
      name = "MEDICAL_RECORD_NUMBER"
    }
    info_types {
      name = "MEDICAL_TERM"
    }

    min_likelihood = "LIKELY"

    limits {
      max_findings_per_request = 100
    }
  }
}

resource "google_data_loss_prevention_deidentify_template" "phi_masking" {
  parent       = "projects/${var.gcp_project_id}"
  display_name = "MedCloud PHI De-identification Template"
  description  = "De-identifies PHI/PII before data enters BigQuery"

  deidentify_config {
    info_type_transformations {
      transformations {
        info_types {
          name = "PERSON_NAME"
        }
        primitive_transformation {
          crypto_replace_ffx_fpe_config {
            crypto_key {
              transient {
                name = "medcloud-dlp-key"
              }
            }
            common_alphabet = "ALPHA_NUMERIC"
          }
        }
      }

      transformations {
        info_types {
          name = "PHONE_NUMBER"
        }
        info_types {
          name = "EMAIL_ADDRESS"
        }
        info_types {
          name = "US_SOCIAL_SECURITY_NUMBER"
        }
        info_types {
          name = "CREDIT_CARD_NUMBER"
        }
        primitive_transformation {
          replace_config {
            new_value {
              string_value = "[REDACTED]"
            }
          }
        }
      }
    }
  }
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# KMS Keys for Analytics Encryption
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

resource "google_kms_key_ring" "analytics" {
  name     = "${local.name_prefix}-analytics-keyring"
  location = "us"
}

resource "google_kms_crypto_key" "bigquery" {
  name            = "${local.name_prefix}-bigquery-key"
  key_ring        = google_kms_key_ring.analytics.id
  rotation_period = "7776000s" # 90 days
}

resource "google_kms_crypto_key" "storage" {
  name            = "${local.name_prefix}-storage-key"
  key_ring        = google_kms_key_ring.analytics.id
  rotation_period = "7776000s"
}

# Grant BigQuery service account access to KMS
data "google_project" "current" {
  project_id = var.gcp_project_id
}

resource "google_kms_crypto_key_iam_member" "bigquery_key" {
  crypto_key_id = google_kms_crypto_key.bigquery.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:bq-${data.google_project.current.number}@bigquery-encryption.iam.gserviceaccount.com"
}

resource "google_kms_crypto_key_iam_member" "storage_key" {
  crypto_key_id = google_kms_crypto_key.storage.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.current.number}@gs-project-accounts.iam.gserviceaccount.com"
}

# ─── Outputs ─────────────────────────────────────────────────────────────────

output "bigquery_ecommerce_dataset" {
  value = google_bigquery_dataset.ecommerce.dataset_id
}

output "bigquery_telemetry_dataset" {
  value = google_bigquery_dataset.medical_telemetry.dataset_id
}

output "data_lake_bucket" {
  value = google_storage_bucket.data_lake.name
}

output "vertex_ai_featurestore" {
  value = google_vertex_ai_featurestore.main.name
}

output "dlp_inspect_template" {
  value = google_data_loss_prevention_inspect_template.phi_detection.id
}

output "dlp_deidentify_template" {
  value = google_data_loss_prevention_deidentify_template.phi_masking.id
}
