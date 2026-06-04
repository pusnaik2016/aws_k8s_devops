# ─────────────────────────────────────────────────────────────
# AWS Security Hub — Centralized Security Posture
# ─────────────────────────────────────────────────────────────
# Compliance: Aggregates findings from GuardDuty, Config,
#             Inspector, Macie into single dashboard.
# Standards:  AWS FSBP, CIS Benchmark, PCI-DSS v3.2.1
# WAF Pillar: Security, Operational Excellence
# ─────────────────────────────────────────────────────────────

resource "aws_securityhub_account" "main" {
  enable_default_standards = false
  auto_enable_controls     = true
  control_finding_generator = "SECURITY_CONTROL"

  depends_on = [aws_guardduty_detector.main]
}

# AWS Foundational Security Best Practices
resource "aws_securityhub_standards_subscription" "aws_foundational" {
  standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/aws-foundational-security-best-practices/v/1.0.0"

  depends_on = [aws_securityhub_account.main]
}

# CIS AWS Foundations Benchmark v1.4.0
resource "aws_securityhub_standards_subscription" "cis" {
  standards_arn = "arn:aws:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.4.0"

  depends_on = [aws_securityhub_account.main]
}

# PCI DSS v3.2.1
resource "aws_securityhub_standards_subscription" "pci_dss" {
  standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/pci-dss/v/3.2.1"

  depends_on = [aws_securityhub_account.main]
}

# Auto-import GuardDuty findings
resource "aws_securityhub_product_subscription" "guardduty" {
  product_arn = "arn:aws:securityhub:${var.aws_region}::product/aws/guardduty"

  depends_on = [aws_securityhub_account.main]
}
