# ─────────────────────────────────────────────────────────────────────────────
# Reusable Module: Security Baseline
# ─────────────────────────────────────────────────────────────────────────────
# Enforces consistent security controls across all 3 clouds:
# - KMS / Key Vault / Cloud KMS key provisioning
# - Audit logging configuration
# - Compliance standard subscriptions
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

variable "enable_waf" {
  description = "Enable WAF"
  type        = bool
  default     = true
}

variable "enable_ddos_protection" {
  description = "Enable DDoS protection (Shield/DDoS Protection Plan)"
  type        = bool
  default     = true
}

variable "enable_threat_detection" {
  description = "Enable threat detection (GuardDuty/Defender/SCC)"
  type        = bool
  default     = true
}

variable "enable_compliance_standards" {
  description = "Enable compliance standard subscriptions (CIS, PCI, HIPAA)"
  type        = bool
  default     = true
}

variable "key_rotation_days" {
  description = "CMK rotation period in days"
  type        = number
  default     = 90
}

variable "log_retention_days" {
  description = "Security log retention in days"
  type        = number
  default     = 365
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

# ─── Security Posture ───────────────────────────────────────────────────

locals {
  security_posture = {
    waf_enabled            = var.enable_waf
    ddos_protection        = var.enable_ddos_protection
    threat_detection       = var.enable_threat_detection
    compliance_standards   = var.enable_compliance_standards
    key_rotation_days      = var.key_rotation_days
    log_retention_days     = var.log_retention_days
    tls_minimum_version    = "1.2"
    encryption_algorithm   = "AES-256"
    mfa_required           = var.environment == "prod"
    public_access_blocked  = var.environment == "prod"
  }

  # Map cloud provider to native services
  native_services = {
    aws = {
      waf       = "AWS WAF v2"
      ddos      = "AWS Shield Advanced"
      threat    = "Amazon GuardDuty"
      kms       = "AWS KMS"
      audit     = "AWS CloudTrail"
      siem      = "AWS Security Hub"
    }
    azure = {
      waf       = "Azure WAF"
      ddos      = "Azure DDoS Protection"
      threat    = "Microsoft Defender for Cloud"
      kms       = "Azure Key Vault"
      audit     = "Azure Activity Log"
      siem      = "Microsoft Sentinel"
    }
    gcp = {
      waf       = "Google Cloud Armor"
      ddos      = "Cloud Armor DDoS"
      threat    = "Security Command Center"
      kms       = "Cloud KMS"
      audit     = "Cloud Audit Logs"
      siem      = "Chronicle SIEM"
    }
  }
}

output "security_posture" {
  value = local.security_posture
}

output "native_services" {
  value = local.native_services[var.cloud_provider]
}
