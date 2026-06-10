# ─────────────────────────────────────────────────────────────────────────────
# Reusable Module: Observability
# ─────────────────────────────────────────────────────────────────────────────
# Shared configuration for deploying consistent monitoring, logging,
# and tracing across all 3 clouds.
# ─────────────────────────────────────────────────────────────────────────────

variable "cloud_provider" {
  description = "Target cloud"
  type        = string
}

variable "name_prefix" {
  description = "Resource naming prefix"
  type        = string
}

variable "environment" {
  description = "Environment"
  type        = string
}

variable "enable_prometheus" {
  description = "Deploy Prometheus for metrics collection"
  type        = bool
  default     = true
}

variable "enable_grafana" {
  description = "Deploy Grafana for visualization"
  type        = bool
  default     = true
}

variable "enable_tracing" {
  description = "Enable distributed tracing (Jaeger/Tempo)"
  type        = bool
  default     = true
}

variable "tracing_sample_rate" {
  description = "Tracing sample rate (0.0 - 1.0)"
  type        = number
  default     = 0.1
}

variable "log_retention_days" {
  description = "Log retention in days"
  type        = number
  default     = 365
}

variable "metrics_retention_days" {
  description = "Metrics retention in days"
  type        = number
  default     = 90
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

# ─── Observability Configuration ────────────────────────────────────────

locals {
  observability_config = {
    metrics = {
      enabled        = var.enable_prometheus
      retention_days = var.metrics_retention_days
      scrape_interval = "15s"
      evaluation_interval = "15s"
    }
    logging = {
      retention_days = var.log_retention_days
      structured     = true
      format         = "json"
    }
    tracing = {
      enabled     = var.enable_tracing
      sample_rate = var.environment == "prod" ? var.tracing_sample_rate : 1.0
      exporter    = "otlp"
    }
    dashboards = {
      grafana_enabled = var.enable_grafana
    }
  }

  # SLO definitions per service
  slo_definitions = {
    storefront_api = {
      availability_target = 0.999      # 99.9%
      latency_p99_target  = 500        # ms
      error_budget_window = "30d"
    }
    patient_service = {
      availability_target = 0.9999     # 99.99% (healthcare-critical)
      latency_p99_target  = 1000       # ms
      error_budget_window = "30d"
    }
    order_service = {
      availability_target = 0.999
      latency_p99_target  = 800
      error_budget_window = "30d"
    }
    ai_gateway = {
      availability_target = 0.995      # 99.5% (ML inference)
      latency_p99_target  = 3000       # ms (model inference)
      error_budget_window = "30d"
    }
  }

  # Map to cloud-native logging sinks
  native_logging = {
    aws   = "CloudWatch Logs"
    azure = "Log Analytics Workspace"
    gcp   = "Cloud Logging"
  }
}

output "observability_config" {
  value = local.observability_config
}

output "slo_definitions" {
  value = local.slo_definitions
}

output "native_logging_service" {
  value = local.native_logging[var.cloud_provider]
}
