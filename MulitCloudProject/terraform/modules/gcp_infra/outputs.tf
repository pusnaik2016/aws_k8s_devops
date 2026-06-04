# =============================================================================
# GCP MODULE OUTPUTS
# =============================================================================

output "vpc_name" {
  value = google_compute_network.main.name
}

output "vpc_self_link" {
  value = google_compute_network.main.self_link
}

output "gke_cluster_endpoint" {
  value     = google_container_cluster.main.endpoint
  sensitive = true
}

output "gke_cluster_name" {
  value = google_container_cluster.main.name
}

output "alloydb_primary_ip" {
  value     = google_alloydb_instance.primary.ip_address
  sensitive = true
}

output "bigquery_audit_dataset_id" {
  value = google_bigquery_dataset.compliance_audit.dataset_id
}

output "bigquery_gdpr_dataset_id" {
  value = google_bigquery_dataset.anonymized_gdpr.dataset_id
}

output "vpn_gateway_ip" {
  value = google_compute_ha_vpn_gateway.main.vpn_interfaces[0].ip_address
}

output "kms_keyring_id" {
  value = google_kms_key_ring.main.id
}
